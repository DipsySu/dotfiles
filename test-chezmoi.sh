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
render ~/.zsh/jetbrains.zsh "$tmpdir/jetbrains.zsh"
render ~/.config/yazi/keymap.toml "$tmpdir/yazi-keymap.toml"

zsh -n "$tmpdir/zshrc"
zsh -n "$tmpdir/zsh_functions"
zsh -n "$tmpdir/zsh_aliases"
zsh -n "$tmpdir/android.zsh"
zsh -n "$tmpdir/help.zsh"
zsh -n "$tmpdir/yazi.zsh"
zsh -n "$tmpdir/ai-tools.zsh"
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

echo "All checks passed."
