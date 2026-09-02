# Yazi 终端文件管理器。配置在 ~/.config/yazi，插件用 `ya pkg install` 恢复。
command -v yazi >/dev/null 2>&1 || return 0

export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-$EDITOR}"

# 用 y 启动，退出后 shell 停留在 yazi 最后所在的目录
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
    rm -f -- "$tmp"
}
