#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d /tmp/dotfiles-bootstrap-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT
fakebin="$tmpdir/bin"
logdir="$tmpdir/log"
mkdir -p "$fakebin" "$logdir"

render_bootstrap() {
    local bootstrap=$1
    local android=$2
    local output=$3
    local config="$tmpdir/config-$bootstrap-$android.yaml"
    cp "$source_dir/.chezmoi.yaml.example" "$config"
    cat >>"$config" <<EOF
  bootstrap_packages: $bootstrap
  enable_android: $android
EOF
    chezmoi --source "$source_dir" --config "$config" execute-template --file \
        "$source_dir/run_once_install-packages.sh.tmpl" >"$output"
    bash -n "$output"
}

cat >"$fakebin/curl" <<'EOF'
#!/bin/bash
if [ "${1:-}" = "-s" ]; then exit 0; fi
printf '%s\n' '#!/bin/bash' # Homebrew installer payload if requested
EOF
cat >"$fakebin/git" <<'EOF'
#!/bin/bash
exit 0
EOF
cat >"$fakebin/brew" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG/brew.args"
for arg in "$@"; do case "$arg" in --file=*) cp "${arg#--file=}" "$TEST_LOG/Brewfile.used";; esac; done
if [ "${FAKE_BREW_FAIL:-0}" = 1 ] && [ "${1:-}" = bundle ]; then exit 7; fi
exit 0
EOF
cat >"$fakebin/mise" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_LOG/mise.args"
[ "${FAKE_MISE_FAIL:-0}" = 1 ] && [ "${1:-}" = install ] && exit 8
exit 0
EOF
cat >"$fakebin/git-lfs" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$fakebin/curl" "$fakebin/git" "$fakebin/brew" "$fakebin/mise" "$fakebin/git-lfs"

render_bootstrap false false "$tmpdir/bootstrap-false.sh"
mkdir -p "$tmpdir/home-false"
TEST_LOG="$logdir" HOME="$tmpdir/home-false" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh \
    bash "$tmpdir/bootstrap-false.sh" >"$logdir/false.out"
[ ! -e "$logdir/brew.args" ] && [ ! -e "$logdir/mise.args" ]

render_bootstrap true false "$tmpdir/bootstrap-true.sh"
mkdir -p "$tmpdir/home-true"
if TEST_LOG="$logdir" HOME="$tmpdir/home-true" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh FAKE_BREW_FAIL=1 \
    bash "$tmpdir/bootstrap-true.sh" >"$logdir/brew-failure.out" 2>&1; then
    echo "expected failed Brew bootstrap to return non-zero" >&2; exit 1
fi
grep -q -- '--no-upgrade' "$logdir/brew.args"
! grep -q 'android-commandlinetools' "$logdir/Brewfile.used"

rm -f "$logdir/brew.args" "$logdir/mise.args"
if TEST_LOG="$logdir" HOME="$tmpdir/home-true" PATH="$fakebin:/usr/bin:/bin" SHELL=/bin/zsh FAKE_MISE_FAIL=1 \
    bash "$tmpdir/bootstrap-true.sh" >"$logdir/mise-failure.out" 2>&1; then
    echo "expected failed Mise bootstrap to return non-zero" >&2; exit 1
fi
grep -qx 'install' "$logdir/mise.args"

# Yazi: unavailable now must not create a stamp; a later apply must retry.
yazi_home="$tmpdir/yazi-home"
yazi_config="$yazi_home/.config/yazi"
yazi_state="$yazi_home/.local/state/chezmoi"
mkdir -p "$yazi_config"
cp "$source_dir/dot_config/yazi/package.toml" "$yazi_config/package.toml"
if HOME="$yazi_home" XDG_CONFIG_HOME="$yazi_home/.config" XDG_STATE_HOME="$yazi_home/.local/state" PATH="/usr/bin:/bin" \
    bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-absent.out"; then :; else exit 1; fi
[ ! -e "$yazi_state/yazi-plugins.sha256" ]

cat >"$fakebin/ya" <<'EOF'
#!/bin/bash
printf '%s\n' install >>"$TEST_LOG/ya.calls"
[ "${FAKE_YA_FAIL:-0}" = 1 ] && exit 9
manifest="${XDG_CONFIG_HOME:-$HOME/.config}/yazi/package.toml"
root="${XDG_CONFIG_HOME:-$HOME/.config}/yazi/plugins"
awk -F'"' '/^\[\[plugin\.deps\]\]/{inside=1;next} /^\[/{inside=0} inside && /^[[:space:]]*use[[:space:]]*=/ {print $2}' "$manifest" |
while IFS= read -r use; do
    name="${use##*:}"; [ "$name" = "$use" ] && name="${use##*/}"; name="${name%.yazi}"
    mkdir -p "$root/$name.yazi"
done
EOF
chmod +x "$fakebin/ya"

yazi_env=(HOME="$yazi_home" XDG_CONFIG_HOME="$yazi_home/.config" XDG_STATE_HOME="$yazi_home/.local/state" TEST_LOG="$logdir" PATH="$fakebin:/usr/bin:/bin")
env "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-first.out"
[ "$(wc -l <"$logdir/ya.calls" | tr -d ' ')" = 1 ]
[ -f "$yazi_state/yazi-plugins.sha256" ]
env "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-second.out"
[ "$(wc -l <"$logdir/ya.calls" | tr -d ' ')" = 1 ]
rm -rf "$yazi_config/plugins/git.yazi"
env "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-repair.out"
[ "$(wc -l <"$logdir/ya.calls" | tr -d ' ')" = 2 ]
cat >>"$yazi_config/package.toml" <<'EOF'

[[plugin.deps]]
use = "example/repo:extra.yazi"
EOF
env "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-manifest-change.out"
[ "$(wc -l <"$logdir/ya.calls" | tr -d ' ')" = 3 ]
stamp_before="$(cat "$yazi_state/yazi-plugins.sha256")"
rm -rf "$yazi_config/plugins/extra.yazi"
if env FAKE_YA_FAIL=1 "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-failure.out" 2>&1; then
    echo "expected failed Yazi installation to return non-zero" >&2; exit 1
fi
[ "$(cat "$yazi_state/yazi-plugins.sha256")" = "$stamp_before" ]
env "${yazi_env[@]}" bash "$source_dir/run_after_install-yazi-plugins.sh.tmpl" >"$logdir/yazi-retry.out"
[ "$(wc -l <"$logdir/ya.calls" | tr -d ' ')" = 5 ]

echo "bootstrap and Yazi checks passed"
