# AI CLI 一律用官方安装器安装，这里只补 PATH / 补全。
# mise 会在提示符和切换目录时刷新 PATH；随后恢复独立安装入口的优先级。
_ai_tools_prefer_native_bin() {
    path=("$HOME/.local/bin" $path)
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _ai_tools_prefer_native_bin
add-zsh-hook chpwd _ai_tools_prefer_native_bin
_ai_tools_prefer_native_bin

# Grok CLI
if [[ -d "$HOME/.grok/bin" ]]; then
    path=("$HOME/.grok/bin" $path)
    [[ -d "$HOME/.grok/completions/zsh" ]] && fpath=("$HOME/.grok/completions/zsh" $fpath)
fi

# Claude Code 常用别名
alias clp='claude --permission-mode bypassPermissions'
alias clpr='claude --permission-mode bypassPermissions -r'
