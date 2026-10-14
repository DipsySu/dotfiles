#!/bin/bash
set -euo pipefail

echo "Testing chezmoi dotfiles..."

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "chezmoi not found"
    exit 1
fi

source_dir="$(cd "$(dirname "$0")" && pwd)"
tmpdir="$(mktemp -d /tmp/dotfiles-chezmoi-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

config_file="$tmpdir/config.yaml"
cp "$source_dir/.chezmoi.yaml.example" "$config_file"
perl -0pi -e 's/nas_ssh: ""/nas_ssh: "legacy-nas"/; s/nas_nfs: ""/nas_nfs: "legacy-nfs"/' "$config_file"
cat >> "$config_file" <<'EOF'
  enable_android: true
  bootstrap_packages: true
  disabled_mise_tools:
    - rust
  extra_mise_tools:
    "npm:obsolete-tool": "latest"
EOF

render() {
    local target=$1
    local output=$2
    chezmoi --source "$source_dir" --config "$config_file" cat "$target" > "$output"
}

render ~/.zshrc "$tmpdir/zshrc"
render ~/.zsh_functions "$tmpdir/zsh_functions"
render ~/.zsh_aliases "$tmpdir/zsh_aliases"
render ~/.zsh/android.zsh "$tmpdir/android.zsh"
render ~/.zsh/help.zsh "$tmpdir/help.zsh"
render ~/.gitconfig "$tmpdir/gitconfig"
render ~/.git-hooks/commit-msg "$tmpdir/commit-msg"
render ~/.config/mise/config.toml "$tmpdir/mise-config.toml"
render ~/.zsh/yazi.zsh "$tmpdir/yazi.zsh"
render ~/.zsh/ai-tools.zsh "$tmpdir/ai-tools.zsh"
render ~/.zsh/grok-proxy.zsh "$tmpdir/grok-proxy.zsh"
chezmoi --source "$source_dir" --config "$config_file" execute-template --file \
    "$source_dir/run_after_ensure-ai-clis.sh.tmpl" > "$tmpdir/ensure-ai-clis.sh"
render ~/.zsh/jetbrains.zsh "$tmpdir/jetbrains.zsh"
render ~/.config/yazi/keymap.toml "$tmpdir/yazi-keymap.toml"

zsh -n "$tmpdir/zshrc"
zsh -n "$tmpdir/zsh_functions"
zsh -n "$tmpdir/zsh_aliases"
zsh -n "$tmpdir/android.zsh"
zsh -n "$tmpdir/help.zsh"
zsh -n "$tmpdir/yazi.zsh"
zsh -n "$tmpdir/ai-tools.zsh"
zsh -n "$tmpdir/grok-proxy.zsh"
bash -n "$tmpdir/ensure-ai-clis.sh"
zsh -n "$tmpdir/jetbrains.zsh"
sh -n "$tmpdir/commit-msg"
git config --file "$tmpdir/gitconfig" --list >/dev/null
if command -v ruby >/dev/null 2>&1; then
    ruby -c "$source_dir/dot_Brewfile" >/dev/null
else
    echo "skip: ruby not found, Brewfile syntax not checked"
fi
if command -v python3 >/dev/null 2>&1; then
    for f in "$tmpdir/mise-config.toml" "$tmpdir/yazi-keymap.toml"; do
        python3 -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" "$f"
    done
fi

# Machine overrides must survive init without becoming nested in another table.
fixture_home="$tmpdir/home"
mkdir -p "$fixture_home/.config/chezmoi"
cat > "$fixture_home/.config/chezmoi/local.toml" <<'EOF'
enable_android = false
bootstrap_packages = false
disabled_mise_tools = []
[extra_mise_tools]
"npm:@google/gemini-cli" = "latest"
[aws]
profiles = []
[home]
nas_ssh = ""
nas_nfs = ""
[shell]
enable_starship = false
[scriptEnv]
CODEX_INSTALLER_USE_RELEASES_OPENAI_COM = "0"
EOF
HOME="$fixture_home" chezmoi --source "$source_dir" --config "$config_file" \
    execute-template --init --file "$source_dir/.chezmoi.toml.tmpl" > "$tmpdir/initialized.toml"
HOME="$fixture_home" chezmoi --source "$source_dir" --config "$tmpdir/initialized.toml" \
    execute-template --file "$source_dir/dot_config/mise/config.toml.tmpl" > "$tmpdir/mise-override.toml"
HOME="$fixture_home" chezmoi --source "$source_dir" --config "$tmpdir/initialized.toml" \
    execute-template --file "$source_dir/.chezmoiignore" > "$tmpdir/ignore-override"
HOME="$fixture_home" chezmoi --source "$source_dir" --config "$tmpdir/initialized.toml" \
    execute-template --file "$source_dir/run_once_install-packages.sh.tmpl" > "$tmpdir/install-override.sh"
bash -n "$tmpdir/install-override.sh"
grep -qx '.zsh/android.zsh' "$tmpdir/ignore-override"
if command -v python3 >/dev/null 2>&1; then
    python3 - "$tmpdir/initialized.toml" "$tmpdir/mise-override.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    config = tomllib.load(f)
extra = {'npm:@google/gemini-cli': 'latest'}
assert config['data']['enable_android'] is False
assert config['data']['bootstrap_packages'] is False
assert config['data'].get('disabled_mise_tools', []) == []
assert config['data']['extra_mise_tools'] == extra
assert 'npm:obsolete-tool' not in config['data']['extra_mise_tools']
assert config['data']['aws']['profiles'] == []
assert config['data']['home']['nas_ssh'] == ''
assert config['data']['home']['nas_nfs'] == ''
assert config['data']['shell']['enable_starship'] is False
assert config['data']['versions']['go'] == 'latest'
assert config['scriptEnv'] == {'CODEX_INSTALLER_USE_RELEASES_OPENAI_COM': '0'}
with open(sys.argv[2], 'rb') as f:
    tools = tomllib.load(f)['tools']
assert tools['rust'] == '1.85.0'
assert tools['flutter'] == '3.35.3'
assert all(tools[k] == v for k, v in extra.items())
PY
fi

# An explicit empty local map must remove every fallback tool from the existing config.
fixture_empty_home="$tmpdir/home-empty"
mkdir -p "$fixture_empty_home/.config/chezmoi"
cat > "$fixture_empty_home/.config/chezmoi/local.toml" <<'EOF'
[extra_mise_tools]
EOF
HOME="$fixture_empty_home" chezmoi --source "$source_dir" --config "$config_file" \
    execute-template --init --file "$source_dir/.chezmoi.toml.tmpl" > "$tmpdir/initialized-empty-extra.toml"
if command -v python3 >/dev/null 2>&1; then
    python3 - "$tmpdir/initialized-empty-extra.toml" <<'PY'
import sys, tomllib
with open(sys.argv[1], 'rb') as f:
    config = tomllib.load(f)
assert 'extra_mise_tools' not in config['data']
PY
fi

bash "$source_dir/test-ai-clis.sh"
bash "$source_dir/test-bootstrap.sh"

echo "All checks passed."
