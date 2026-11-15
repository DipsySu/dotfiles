#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d /tmp/dotfiles-ssh-path-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
    echo "test-ssh-path: $*" >&2
    exit 1
}

make_executable() {
    local path=$1
    local value=$2
    mkdir -p "$(dirname "$path")"
    printf '%s\n' '#!/bin/sh' "printf '%s\\n' '$value'" > "$path"
    chmod +x "$path"
}

copy_startup_files() {
    local zdotdir=$1
    mkdir -p "$zdotdir"
    cp "$source_dir/dot_zshenv" "$zdotdir/.zshenv"
    cp "$source_dir/dot_zprofile" "$zdotdir/.zprofile"
    printf 'printf "zshrc-read\\n" > "$HOME/zshrc-read"\n' > "$zdotdir/.zshrc"
}

fixture_home="$tmpdir/home"
zdotdir="$tmpdir/zdotdir"
mkdir -p "$fixture_home/.local/bin" "$fixture_home/.grok/bin" "$fixture_home/venv/bin"
copy_startup_files "$zdotdir"

make_executable "$fixture_home/.local/bin/codex" native-codex
make_executable "$fixture_home/.local/bin/claude" native-claude
make_executable "$fixture_home/.local/bin/agy" native-agy
make_executable "$fixture_home/.grok/bin/grok" native-grok
make_executable "$fixture_home/venv/bin/venv-tool" venv-tool

mise_data="$tmpdir/mise-data"
xdg_data="$tmpdir/xdg-data"
explicit_shims="$tmpdir/explicit shims"
mkdir -p "$mise_data/shims" "$xdg_data/mise/shims" "$explicit_shims"
make_executable "$mise_data/shims/codex" stale-mise-codex
make_executable "$mise_data/shims/go" mise-go
make_executable "$mise_data/shims/java" mise-java
make_executable "$mise_data/shims/node" mise-node
make_executable "$mise_data/shims/selector" mise-data
make_executable "$xdg_data/mise/shims/selector" xdg-data
make_executable "$explicit_shims/selector" explicit-shims

# zsh -c must load .zshenv (without -f), remain silent, retain custom paths,
# and prefer native CLIs over a same-named mise shim.
stdout_file="$tmpdir/stdout"
stderr_file="$tmpdir/stderr"
if ! env -u MISE_SHIMS_DIR -u XDG_DATA_HOME \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" MISE_DATA_DIR="$mise_data" \
    TEST_MISSING_PATH="$tmpdir/missing custom" \
    PATH="$fixture_home/venv/bin:$tmpdir/missing custom:/usr/bin:/bin:/usr/sbin:/sbin" \
    zsh -ec '
        [[ "$(codex)" == native-codex ]]
        [[ "$(claude)" == native-claude ]]
        [[ "$(agy)" == native-agy ]]
        [[ "$(grok)" == native-grok ]]
        [[ "$(go)" == mise-go && "$(java)" == mise-java && "$(node)" == mise-node ]]
        [[ "$(venv-tool)" == venv-tool ]]
        [[ "$path[1]" == "$HOME/.local/bin" && "$path[2]" == "$HOME/.grok/bin" ]]
        [[ "${path[(I)$HOME/venv/bin]}" -lt "${path[(I)$MISE_DATA_DIR/shims]}" ]]
        [[ "${path[(I)$TEST_MISSING_PATH]}" -gt 0 ]]
    ' >"$stdout_file" 2>"$stderr_file"; then
    fail "non-interactive zsh command lookup failed"
fi
[[ ! -s "$stdout_file" && ! -s "$stderr_file" ]] || fail "startup produced output"
[[ ! -e "$fixture_home/zshrc-read" ]] || fail ".zshrc was read by a non-interactive shell"

# Re-sourcing .zshenv must not add duplicates or lose a custom inherited path.
env -u MISE_SHIMS_DIR -u XDG_DATA_HOME \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" MISE_DATA_DIR="$mise_data" \
    PATH="$fixture_home/venv/bin:/usr/bin:/bin" zsh -ec '
        before=("${path[@]}")
        source "$ZDOTDIR/.zshenv"
        typeset -A seen
        for dir in "${path[@]}"; do
            [[ -n "$dir" && -z "${seen[$dir]-}" ]] || exit 1
            seen[$dir]=1
        done
        (( $#path == $#before ))
        for (( i = 1; i <= $#before; ++i )); do
            [[ "${path[i]}" == "${before[i]}" ]] || exit 1
        done
        [[ "${path[(I)$HOME/venv/bin]}" -lt "${path[(I)$MISE_DATA_DIR/shims]}" ]]
    ' || fail "re-sourcing .zshenv was not idempotent"

# Explicit MISE_SHIMS_DIR wins, then MISE_DATA_DIR, then XDG_DATA_HOME.
env -u MISE_DATA_DIR -u XDG_DATA_HOME \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" MISE_SHIMS_DIR="$explicit_shims" \
    MISE_DATA_DIR="$mise_data" XDG_DATA_HOME="$xdg_data" PATH="/usr/bin:/bin" \
    zsh -ec '[[ "$(selector)" == explicit-shims ]]' || fail "MISE_SHIMS_DIR did not win"
env -u MISE_SHIMS_DIR \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" MISE_DATA_DIR="$mise_data" XDG_DATA_HOME="$xdg_data" \
    PATH="/usr/bin:/bin" zsh -ec '[[ "$(selector)" == mise-data ]]' || fail "MISE_DATA_DIR did not win"
env -u MISE_SHIMS_DIR -u MISE_DATA_DIR \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" XDG_DATA_HOME="$xdg_data" PATH="/usr/bin:/bin" \
    zsh -ec '[[ "$(selector)" == xdg-data ]]' || fail "XDG_DATA_HOME fallback failed"

# A true login shell runs .zprofile after macOS path_helper; it must restore
# native-before-custom-before-mise ordering and remain quiet.
: > "$stdout_file"
: > "$stderr_file"
if ! env -u MISE_SHIMS_DIR -u XDG_DATA_HOME \
    HOME="$fixture_home" ZDOTDIR="$zdotdir" MISE_DATA_DIR="$mise_data" \
    PATH="/usr/bin:$fixture_home/venv/bin:/bin:/usr/sbin:/sbin" \
    zsh -elc '
        [[ "$path[1]" == "$HOME/.local/bin" && "$path[2]" == "$HOME/.grok/bin" ]]
        [[ "${path[(I)$HOME/venv/bin]}" -lt "${path[(I)$MISE_DATA_DIR/shims]}" ]]
        [[ "$(codex)" == native-codex && "$(go)" == mise-go ]]
    ' >"$stdout_file" 2>"$stderr_file"; then
    fail "non-interactive login zsh ordering failed"
fi
[[ ! -s "$stdout_file" && ! -s "$stderr_file" ]] || fail "login startup produced output"

# Missing optional directories must not be invented or prevent startup.
empty_home="$tmpdir/empty-home"
empty_zdotdir="$tmpdir/empty-zdotdir"
mkdir -p "$empty_home"
copy_startup_files "$empty_zdotdir"
env -u MISE_DATA_DIR -u XDG_DATA_HOME \
    HOME="$empty_home" ZDOTDIR="$empty_zdotdir" MISE_SHIMS_DIR="$tmpdir/not-present" \
    PATH="/usr/bin:/bin" zsh -ec ':' >"$stdout_file" 2>"$stderr_file" || fail "missing optional directories broke startup"
[[ ! -s "$stdout_file" && ! -s "$stderr_file" ]] || fail "missing-directory startup produced output"

echo "SSH non-interactive PATH checks passed."
