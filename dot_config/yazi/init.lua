-- Yazi 26.9.1 · init.lua
-- 插件通过 `ya pkg` 管理，见 package.toml；换机器后执行 `ya pkg install` 即可恢复

-- 圆角完整边框
require("full-border"):setup { type = ui.Border.ROUNDED }

-- 文件列表旁显示 git 状态（fetcher 已在 yazi.toml 注册，颜色在 flavor 的 [git] 段）
require("git"):setup()

-- 顶部用 starship 提示符，和 zsh 里保持一致（读取 ~/.config/starship.toml）
require("starship"):setup()

-- 按扩展名快速判断 MIME（/mnt/c 上明显更快）；识别不到时回退 file(1)
require("mime-ext.local"):setup { fallback_file1 = true }

-- 自定义 linemode：大小 + 修改时间（今年只显示 月-日 时:分）
function Linemode:size_and_mtime()
	local time = math.floor(self._file.cha.mtime or 0)
	if time == 0 then
		time = ""
	elseif os.date("%Y", time) == os.date("%Y") then
		time = os.date("%m-%d %H:%M", time)
	else
		time = os.date("%Y-%m-%d", time)
	end

	local size = self._file:size()
	return string.format("%s %s", size and ya.readable_size(size) or "-", time)
end
