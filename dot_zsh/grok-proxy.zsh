# 本地代理可用时，仅让本次 Grok CLI 走 HTTP 代理。
grok() {
    local port="${GROK_PROXY_PORT:-7897}"
    local REPLY
    if [[ ! "$port" == <1-65535> ]]; then
        print -u2 'grok: GROK_PROXY_PORT 必须是 1-65535 的端口号'
        return 2
    fi

    zmodload zsh/net/tcp 2>/dev/null
    if ! ztcp 127.0.0.1 "$port" >/dev/null 2>&1; then
        command grok "$@"
        return $?
    fi
    local ztcp_fd="$REPLY"
    ztcp -c "$ztcp_fd" >/dev/null 2>&1

    local grok_proxy_url="http://127.0.0.1:$port"
    # 本地服务与智谱 MCP 保持直连，并合并调用者已有的绕过列表。
    local grok_no_proxy="localhost,127.0.0.1,::1,api.z.ai${NO_PROXY:+,$NO_PROXY}${no_proxy:+,$no_proxy}"

    HTTP_PROXY="$grok_proxy_url" HTTPS_PROXY="$grok_proxy_url" \
    http_proxy="$grok_proxy_url" https_proxy="$grok_proxy_url" \
    NO_PROXY="$grok_no_proxy" no_proxy="$grok_no_proxy" \
        command grok "$@"
}
