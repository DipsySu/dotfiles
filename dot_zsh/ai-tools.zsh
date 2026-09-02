# AI CLI 一律用官方安装器安装，这里只补 PATH / 补全。
# Claude Code、Antigravity 装到 ~/.local/bin，已在 PATH 里，无需处理。

# Grok CLI
if [[ -d "$HOME/.grok/bin" ]]; then
    path=("$HOME/.grok/bin" $path)
    [[ -d "$HOME/.grok/completions/zsh" ]] && fpath=("$HOME/.grok/completions/zsh" $fpath)
fi

# Claude Code 常用别名
alias clp='claude --permission-mode bypassPermissions'
alias clpr='claude --permission-mode bypassPermissions -r'
