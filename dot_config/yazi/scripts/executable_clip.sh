#!/bin/sh
# 把 stdin 复制到 Windows 剪贴板（去掉末尾换行）。
# 优先 wl-copy：WSLg 会自动同步到 Windows 剪贴板，UTF-8 不会乱码；
# 没装 wl-clipboard 时回退 PowerShell Set-Clipboard，通过 UTF-8 临时文件传递，避开控制台代码页问题。
set -eu
content="$(cat)"
if command -v wl-copy >/dev/null 2>&1; then
	printf '%s' "$content" | wl-copy
elif command -v xclip >/dev/null 2>&1; then
	printf '%s' "$content" | xclip -selection clipboard
else
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' EXIT
	printf '%s' "$content" > "$tmp"
	powershell.exe -NoProfile -NonInteractive -Command \
		"Set-Clipboard -Value (Get-Content -Raw -Encoding UTF8 -LiteralPath '$(wslpath -w "$tmp")')"
fi
