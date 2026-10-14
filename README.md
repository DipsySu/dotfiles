# 🚀 Dotfiles - 一键配置开发环境

这是一个跨平台的 dotfiles 配置，支持 WSL、Linux、Intel Mac 和 Apple Silicon Mac，使用 Chezmoi + Homebrew + Mise 的现代化工具链。

## ✨ 特性

- 🔧 **一键安装**: 单条命令完成整个开发环境配置
- 🌍 **跨平台支持**: WSL、Linux、Intel Mac、Apple Silicon Mac 兼容
- 📦 **现代工具链**: Starship、Zoxide、Eza、FZF 等现代 CLI 工具
- 🎯 **智能管理**: 自动安装 Node.js、Python、Go、Java 等运行时
- 🔄 **版本控制**: 使用 Chezmoi 管理配置文件版本
- ⚙️ **高度可配置**: 支持模板变量自定义配置

## 🚀 快速开始

### 新 MacBook Air / Apple Silicon 一键安装

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/DipsySu/dotfiles/master/quick-install.sh)"
```

这个脚本会：
1. 检查 Xcode Command Line Tools
1. 自动安装 Chezmoi 到 `~/.local/bin`
2. 从 GitHub 拉取配置
3. 交互式配置个人信息
4. 自动识别 Apple Silicon 的 `/opt/homebrew` 或 Intel Mac 的 `/usr/local`
5. 自动运行安装脚本，安装开发工具、CLI、mise 运行时和 zsh 插件管理器

### 手动安装 (如果你想更多控制)

```bash
# 安装 chezmoi 并初始化配置
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply DipsySu

# 临时设置 PATH (重启终端后会自动生效)
export PATH="$HOME/.local/bin:$PATH"

# 重新加载配置
source ~/.zshrc
```

### 跳过交互式配置

推荐做法：把私有值写进 `~/.config/chezmoi/local.toml`（不进仓库），`chezmoi init` 会自动读取、不再提问，格式见 `TIPS.md`「私有变量 local.toml」。下面是另一种手写完整配置的方式：

如果你想使用默认配置，可以预先创建配置文件：

```bash
# 创建配置目录
mkdir -p ~/.config/chezmoi

# 创建配置文件
cat > ~/.config/chezmoi/chezmoi.yaml << 'EOF'
data:
  name: "Your Name"
  email: "your.email@example.com"
  versions:
    go: "latest"
    java: "temurin-21"
    node: "lts"
    python: "3.11"
  shell:
    enable_starship: true
    enable_zoxide: true
    enable_eza: true
EOF

# 然后运行 chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply DipsySu
```

## 📦 包含的工具

### 核心工具
- **Chezmoi**: 配置文件管理
- **Homebrew**: 包管理器
- **Mise**: 运行时版本管理 (替代 nvm, pyenv 等)
- **Mise 运行时保留**: 升级后不自动安排删除旧版本；已有的延迟删除计划需另行检查
- **Zinit**: 轻量 Zsh 插件管理器

### CLI 工具
- **Starship**: 现代化提示符
- **Zoxide**: 智能 cd 命令
- **Eza**: 现代化 ls 命令
- **Bat**: 更好的 cat 命令
- **FZF**: 模糊搜索工具
- **Ripgrep**: 快速文本搜索
- **fd**: 现代化 find 命令

### 开发运行时
- **Node.js**: LTS 版本
- **Python**: 3.11
- **Go**: 最新版本
- **Java**: Temurin 21

### 独立 CLI 安装与代理

每次 `chezmoi apply` 都会运行 `run_after_ensure-ai-clis.sh.tmpl`，检查以下官方安装入口。已安装的工具保持当前版本，缺失时才下载安装；安装不包含登录或模型请求。

| 工具 | 安装入口 | 缺失时的版本 |
| --- | --- | --- |
| [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) | `~/.local/bin/codex` | 官方 latest |
| [Claude Code](https://code.claude.com/docs/en/setup) | `~/.local/bin/claude` | 官方 latest |
| [Google Antigravity CLI](https://codelabs.developers.google.com/antigravity-cli-hands-on) | `~/.local/bin/agy` | 官方 latest |
| [Grok Build](https://docs.x.ai/build/overview) | `~/.grok/bin/grok`、`~/.grok/bin/agent` | 官方 stable |

安装逻辑位于 `scripts/ensure-ai-clis.sh`。Grok 的 `grok` 和 `agent` 共用同一二进制；脚本也会补齐缺失的 `~/.local/bin` 入口。`agy` 是 Antigravity CLI，Antigravity IDE 需单独安装。

Shell 配置由 chezmoi 统一管理。Antigravity 安装器的临时副本仅调整末尾的 setup 调用，添加官方支持的 `--skip-path --skip-aliases`；官方的下载和 SHA-512 校验流程保持完整。安装器布局变化时会停止该项安装。Codex / Claude 安装期间保留已有 shell 配置，Claude 的用户 settings 也会保留，避免安装迁移改写模型选项。安装被中断或恢复失败时，脚本会保留备份目录并输出路径。

`dot_zsh/ai-tools.zsh` 会在 mise 刷新 PATH 后恢复 `~/.local/bin` 的优先级。`dot_zsh/grok-proxy.zsh` 管理 Grok 的本地代理：默认检查 `127.0.0.1:7897`，监听存在时仅为本次 Grok 进程设置代理；未监听时保留调用者的网络设置。可临时指定其他本地端口：

```zsh
GROK_PROXY_PORT=7890 grok login
```

日常升级使用各工具的官方更新命令：

```zsh
codex update
claude update
agy update
grok update --stable
```

### Zsh 插件
- **fast-syntax-highlighting**: 语法高亮
- **zsh-completions**: 补全增强

## ⚙️ 配置说明

### 自定义配置文件 (profile.yaml)

```yaml
# Git 配置
git:
  name: "Your Name"
  email: "your.email@example.com"

# 开发工具版本
versions:
  go: "latest"
  java: "temurin-21"
  node: "lts"
  python: "3.11"
  flutter: "3.35.3"

# Shell 功能开关
shell:
  enable_starship: true
  enable_zoxide: true
  enable_eza: true
```

### 环境变量

安装完成后，以下路径会自动添加到 PATH：
- `$HOME/.local/bin` - Chezmoi 和其他本地工具
- `/home/linuxbrew/.linuxbrew/bin` - Homebrew (Linux)
- `/opt/homebrew/bin` - Homebrew (Apple Silicon macOS)
- `/usr/local/bin` - Homebrew (Intel macOS)

### 每台机器的工具链配置

把机器差异写入私有的 `~/.config/chezmoi/local.toml`，然后运行 `chezmoi init` 和 `chezmoi apply`。例如，保留已有 Rust，禁用 Android，并继续用 mise 管理 Gemini：

```toml
enable_android = false
disabled_mise_tools = ["rust"]

[extra_mise_tools]
"npm:@google/gemini-cli" = "latest"
```

未设置这些选项时保持默认工具链。禁用 Android 会跳过其 shell 模块和初始化安装项；已经存在的 `~/.zsh/android.zsh` 需先备份移出该目录。未由 mise 管理的 Rust 仍可通过 `~/.cargo/bin` 使用。

`local.toml` 的显式值优先，包括 `false`、空字符串和空数组。`extra_mise_tools` 会整体替换旧配置中的同名表，删除的工具不会在下次初始化时重新出现。

已经配置好的机器可以在 `local.toml` 的顶层添加 `bootstrap_packages = false`，跳过整套 Homebrew 和 mise 的首次安装任务。新机器默认启用该任务；启用时 Homebrew 只补齐缺失的软件，不升级已有软件。必要安装步骤失败会返回错误，下次 apply 可以重试。原生 CLI 的缺失检查仍会执行。

Yazi 插件会在每次 apply 时检查：未安装 `ya` 时跳过，安装后自动补齐；只有清单变化、插件目录缺失或上次安装失败时才运行安装命令。

### 保留机器私有设置

- `~/.zshrc.local`：在所有公共 shell 配置之后加载，适合 iTerm2 Shell Integration、个人快捷键和本机路径。
- `~/.gitconfig.local`：由主 Git 配置 include，适合 GitHub credential helper 和其他机器私有 Git 设置。

这两个文件不纳入仓库，也不会被 apply 覆盖。把已有自定义内容移入对应文件后，再应用模板。

如果 Codex 主下载站连接失败，可以在该机器的 `local.toml` 中添加官方安装器支持的下载源选项；这只影响缺失时的安装：

```toml
[scriptEnv]
CODEX_INSTALLER_USE_RELEASES_OPENAI_COM = "0"
```

### Apple Silicon / MacBook Air 注意事项

- Homebrew 默认在 `/opt/homebrew`，配置会自动检测，不要手写 `/usr/local`。
- Codex、Claude Code、Antigravity CLI 和 Grok Build 使用上述独立安装任务，运行入口优先于旧 mise shim。
- Android SDK 会优先使用 `~/Library/Android/sdk`，再回退到 Homebrew 的 `android-commandlinetools` 路径。
- Docker/OrbStack 默认不安装；如果项目需要 Docker，再手动安装 OrbStack 或 Docker Desktop。
- 外接 4K 显示器时可按需安装 BetterDisplay，默认只安装 MonitorControl、Rectangle、Stats。

## 🔧 常用命令

### Chezmoi 管理
```bash
# 查看当前配置
chezmoi data

# 编辑配置文件
chezmoi edit ~/.zshrc

# 应用更改
chezmoi apply

# 更新配置
chezmoi update
```

### Mise 运行时管理
```bash
# 查看已安装版本
mise ls

# 验证 AI coding CLI
codex --version
claude --version
agy --version
grok --version

# 安装新版本
mise install node@20

# 切换全局版本
mise use -g node@20

# 项目级版本
mise use node@18
```

### 同步配置
```bash
# 推送更改到 GitHub
cd ~/.local/share/chezmoi
git add .
git commit -m "update configs"
git push
```

## 🏠 家居自动化功能

如果你使用 Tailscale 进行远程控制，配置包含以下自定义函数：

```bash
# 远程唤醒家用电脑
wake_home

# SSH 连接到家用路由器
ssh_istore

# 远程休眠家用电脑
sleep_home

# 查看家用电脑状态
check_home
```

## 🔍 故障排除

### 命令找不到
```bash
# 重新加载 shell 配置
source ~/.zshrc

# 或重启终端
exec zsh

# 检查 PATH
echo $PATH
```

### 权限问题
```bash
# 确保目录权限正确
sudo chown -R $(whoami) ~/.local/share/chezmoi
```

### Homebrew 问题
```bash
# 手动设置 Homebrew 环境 (Linux)
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# 手动设置 Homebrew 环境 (macOS)
eval "$(/opt/homebrew/bin/brew shellenv)"
```

## 📝 自定义

### 添加新的软件包
编辑 `Brewfile`:
```ruby
brew "your-package"
cask "your-app"  # macOS only
```

### 修改 Zsh 配置
```bash
chezmoi edit ~/.zshrc
chezmoi apply
```

### 添加自定义函数
```bash
chezmoi edit ~/.zsh_functions
chezmoi apply
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

MIT License

---

**享受你的现代化开发环境！** 🎉
