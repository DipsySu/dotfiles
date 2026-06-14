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

zsh -n "$tmpdir/zshrc"
zsh -n "$tmpdir/zsh_functions"
zsh -n "$tmpdir/zsh_aliases"
zsh -n "$tmpdir/android.zsh"
zsh -n "$tmpdir/help.zsh"
sh -n "$tmpdir/commit-msg"
git config --file "$tmpdir/gitconfig" --list >/dev/null
ruby -c "$source_dir/dot_Brewfile" >/dev/null

echo "All checks passed."
