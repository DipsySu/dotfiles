#!/bin/sh
# 用 WPS Office 打开文件（yazi opener）。
#   WSL  ：从注册表读 WPS 注册的 wps.exe 路径（随版本升级自动跟随，结果缓存），按扩展名选组件。
#   macOS：open -a wpsoffice。
#   找不到 WPS 时交给系统默认程序。
#   wps.sh --which  只打印解析到的 wps.exe 路径，不打开任何东西。
set -u

case "$(uname -s)" in
Darwin)
	[ "${1:-}" = "--which" ] && { osascript -e 'POSIX path of (path to application "wpsoffice")' 2>/dev/null || echo "wpsoffice.app 未找到"; exit 0; }
	open -a wpsoffice "$@" 2>/dev/null || open -a "WPS Office" "$@" 2>/dev/null || open "$@"
	exit $?
	;;
esac

cache="${XDG_CACHE_HOME:-$HOME/.cache}/yazi-wps-exe"
exe=""
[ -r "$cache" ] && exe="$(cat "$cache")"
if [ -z "$exe" ] || [ ! -f "$exe" ]; then
	# reg.exe 输出里的“(默认)”是 GBK 字节，必须用 LC_ALL=C 让 sed 按字节匹配
	win="$(reg.exe query 'HKCR\WPS.Docx.6\shell\open\command' /ve 2>/dev/null | tr -d '\r' | LC_ALL=C sed -n 's/.*REG_SZ[[:space:]]*"\([^"]*\.[Ee][Xx][Ee]\)".*/\1/p' | head -n 1)"
	exe=""
	if [ -n "$win" ]; then
		exe="$(wslpath -u "$win" 2>/dev/null || true)"
		if [ -n "$exe" ] && [ -f "$exe" ]; then
			mkdir -p "$(dirname "$cache")" && printf '%s' "$exe" > "$cache"
		else
			exe=""
		fi
	fi
fi

if [ "${1:-}" = "--which" ]; then
	echo "${exe:-（未找到 WPS，将回退到系统默认程序）}"
	exit 0
fi

# 先把路径都转成 Windows 形式，再切到 /mnt/c 启动，避开 UNC 工作目录的告警
wins=""
for f in "$@"; do
	wins="$wins$(wslpath -w "$f")
"
done
cd /mnt/c 2>/dev/null || true
printf '%s' "$wins" | while IFS= read -r w; do
	[ -n "$w" ] || continue
	if [ -z "$exe" ]; then
		explorer.exe "$w"
		continue
	fi
	f="$w"
	ext="$(printf '%s' "${f##*.}" | tr 'A-Z' 'a-z')"
	case "$ext" in
	xls | xlsx | xlsm | xlsb | csv | et | ett | ods) comp=/et ;;
	ppt | pptx | pptm | pps | ppsx | dps | dpt | odp) comp=/wpp ;;
	pdf) comp=/pdf ;;
	*) comp=/wps ;;
	esac
	"$exe" /prometheus "$comp" "$w" &
done
wait
