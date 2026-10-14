#!/bin/bash
set -euo pipefail

source_dir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d /tmp/dotfiles-git-shell-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

config="$tmpdir/config.yaml"
cp "$source_dir/.chezmoi.yaml.example" "$config"
python3 - "$config" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace('name: "Your Name"', 'name: "Jane # Work \\\"Team\\\"\\\\"')
text = text.replace('email: "your.email@example.com"', 'email: "jane@example.test"')
path.write_text(text)
PY

gitconfig="$tmpdir/gitconfig"
zshrc="$tmpdir/zshrc"
hook="$tmpdir/commit-msg"
render_home="$tmpdir/render-home"
mkdir -p "$render_home"
HOME="$render_home" chezmoi --source "$source_dir" --destination "$render_home" --config "$config" cat "$render_home/.gitconfig" >"$gitconfig"
HOME="$render_home" chezmoi --source "$source_dir" --destination "$render_home" --config "$config" cat "$render_home/.zshrc" >"$zshrc"
HOME="$render_home" chezmoi --source "$source_dir" --destination "$render_home" --config "$config" cat "$render_home/.git-hooks/commit-msg" >"$hook"

git_fixture() {
    HOME="$render_home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$gitconfig" git "$@"
}

must_not() {
    if "$@"; then
        echo "unexpected success: $*" >&2
        exit 1
    fi
}

sh -n "$hook"
zsh -n "$zshrc"
[ "$(git_fixture config --file "$gitconfig" --get user.name)" = 'Jane # Work "Team"\' ]
[ "$(git_fixture config --file "$gitconfig" --get user.email)" = 'jane@example.test' ]
[ "$(git_fixture config --file "$gitconfig" --get core.excludesfile)" = "$render_home/.gitignore_global" ]
must_not git_fixture config --file "$gitconfig" --get core.hooksPath >/dev/null
must_not git_fixture config --file "$gitconfig" --get http.proxy >/dev/null
must_not git_fixture config --file "$gitconfig" --get https.proxy >/dev/null
must_not grep -Eq 'git[[:space:]]+clone|https://github.com/zdharma-continuum/zinit' "$zshrc"

# A global config without hooksPath must leave ordinary repository hooks alone,
# including a linked worktree which shares its hooks directory.
repo="$tmpdir/repo"
git_fixture init -q "$repo"
mkdir -p "$repo/.git/hooks"
cat >"$repo/.git/hooks/commit-msg" <<'EOF'
#!/bin/sh
printf '%s\n' "$1" >>"$HOOK_LOG"
EOF
chmod +x "$repo/.git/hooks/commit-msg"
printf 'one\n' >"$repo/one"
HOOK_LOG="$tmpdir/hooks.log" git_fixture -C "$repo" add one
HOOK_LOG="$tmpdir/hooks.log" git_fixture -C "$repo" commit -qm first
git_fixture -C "$repo" worktree add -q "$tmpdir/worktree" -b topic
printf 'two\n' >"$tmpdir/worktree/two"
HOOK_LOG="$tmpdir/hooks.log" git_fixture -C "$tmpdir/worktree" add two
HOOK_LOG="$tmpdir/hooks.log" git_fixture -C "$tmpdir/worktree" commit -qm second
[ "$(wc -l <"$tmpdir/hooks.log" | tr -d ' ')" = 2 ]

# The optional hook removes only explicit machine identities; human trailers
# remain intact for repository-local use.
message="$tmpdir/message"
cat >"$message" <<'EOF'
subject

Co-authored-by: Jane Example <jane@example.test>
Co-authored-by: Claude <claude@example.test>
Co-authored-by: Codex <noreply@openai.com>
co-authored-by: Claude <noreply@anthropic.com>
Co-authored-by: OpenAI <noreply@openai.com>
EOF
sh "$hook" "$message"
grep -Fqx 'Co-authored-by: Jane Example <jane@example.test>' "$message"
grep -Fqx 'Co-authored-by: Claude <claude@example.test>' "$message"
must_not grep -Fxiq 'Co-authored-by: Codex <noreply@openai.com>' "$message"
must_not grep -Fxiq 'Co-authored-by: Claude <noreply@anthropic.com>' "$message"
must_not grep -Fxiq 'Co-authored-by: OpenAI <noreply@openai.com>' "$message"

echo "git and shell checks passed"
