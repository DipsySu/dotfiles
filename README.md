# 🚀 Dotfiles - 一键配置开发环境

这是一个跨平台的 dotfiles 配置，支持 WSL、Linux 和 macOS，使用 Chezmoi + Homebrew + Mise 的现代化工具链。

## ✨ 特性

- 🔧 **一键安装**: 单条命令完成整个开发环境配置
- 🌍 **跨平台支持**: WSL、Linux、macOS 完美兼容
- 📦 **现代工具链**: Starship、Zoxide、Eza、FZF 等现代 CLI 工具
- 🎯 **智能管理**: 自动安装 Node.js、Python、Go、Java 等运行时
- 🔄 **版本控制**: 使用 Chezmoi 管理配置文件版本
- ⚙️ **高度可配置**: 支持模板变量自定义配置

## 🚀 快速开始

### 一键安装 (推荐)

```bash
# 使用一键安装脚本 (自动处理所有 PATH 问题)
curl -fsSL https://raw.githubusercontent.com/DipsySu/dotfiles/main/quick-install.sh | bash
```

这个脚本会：
1. 自动安装 Chezmoi 到 `~/.local/bin`
2. 从 GitHub 拉取配置
3. 交互式配置个人信息
4. **自动设置永久 PATH**
5. 自动运行安装脚本，安装所有开发工具

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
- **Oh My Zsh**: Zsh 框架

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

### Zsh 插件
- **zsh-autosuggestions**: 命令自动建议
- **zsh-syntax-highlighting**: 语法高亮

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
- `/opt/homebrew/bin` - Homebrew (macOS)

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