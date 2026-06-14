# Dotfiles 使用指南 & 备忘录 (TIPS.md)

本文档记录了本套 Dotfiles 的架构逻辑、常用命令以及在新机器上的恢复流程。

## 1. 核心架构

*   **配置管理**: [Chezmoi](https://www.chezmoi.io/) - 负责同步 `.zshrc`, `.gitconfig`、Git hooks 以及 Mise 的全局配置。
*   **运行时管理**: [Mise](https://mise.jdx.dev/) - 替代 nvm, pyenv, rbenv。负责安装 Node, Python, Java, Go。
*   **包管理**: Homebrew - 负责安装 CLI 工具 (git, fzf, starship 等)。
*   **Shell 插件**: Zinit - 替代完整 Oh My Zsh，启动更轻。

---

## 2. 新机器初始化 (Bootstrap)

在全新的 macOS 或 WSL (Ubuntu) 上，只需执行以下步骤：

### 步骤 A: 一键安装 (推荐方式)

```bash
# 方法一：使用一键安装脚本 (自动处理 PATH)
curl -fsSL https://raw.githubusercontent.com/DipsySu/dotfiles/main/quick-install.sh | bash

# 方法二：手动安装 (需要手动设置 PATH)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply DipsySu
export PATH="$HOME/.local/bin:$PATH"  # 临时设置，重启终端后生效
source ~/.zshrc
```

**推荐使用方法一**，它会自动处理所有 PATH 设置问题。

该命令会自动完成以下工作：
1. 安装 `chezmoi` 二进制文件到 `~/.local/bin`
2. 拉取你的 Dotfiles 仓库
3. 提示你输入配置变量（Git用户名、邮箱等）
4. 将配置文件映射到 `~` 目录
5. **自动运行 `run_once_install-packages.sh` 脚本**，安装：
   - Homebrew 包管理器
   - 开发工具 (starship, eza, zoxide 等)
   - Zinit 和 zsh 插件
   - 运行时环境 (Node.js, Python, Go, Java)
   - Codex / Claude Code / Gemini CLI

### 步骤 B: 跳过交互式配置 (可选)

如果你想跳过交互式配置，可以预先创建配置文件：

```bash
# 1. 创建配置目录
mkdir -p ~/.config/chezmoi

# 2. 创建静态配置文件
cat > ~/.config/chezmoi/chezmoi.yaml << 'EOF'
data:
  name: "Dipsy"
  email: "suqiankun@johnsonfitness.com"
  versions:
    go: "latest"
    java: "temurin-21"
    node: "lts"
    python: "3.11"
    flutter: "3.35.3"
  aws:
    cn_region: "cn-north-1"
    sg_region: "ap-southeast-1"
    codeartifact_domain: "nautilus"
  home:
    tailscale_path: ""
    ssh_host: "home-pc"
    pc_ip: "192.168.50.197"
  shell:
    enable_starship: true
    enable_zoxide: true
    enable_eza: true
EOF

# 3. 然后运行 chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply DipsySu
```

---

## 3. Mise 使用指南 (运行时管理)

Mise 统一管理所有语言版本。配置文件的优先级：`Shell 临时` > `项目级 (.mise.toml)` > `全局 (~/.config/mise/config.toml)`。

### 常用场景

| 场景 | NVM/Pyenv 操作 | **Mise 操作 (推荐)** | 备注 |
| :--- | :--- | :--- | :--- |
| **临时切换** (当前窗口) | `nvm use 20` | `mise use node@20` | 仅当前 Session 有效 |
| **设置全局默认** | `nvm alias default 20` | `mise use -g node@20` | **修改后需同步 Chezmoi** |
| **项目级锁定** | 创建 `.nvmrc` | `mise use node@16` | 在项目目录下运行，会自动生成 `.mise.toml` |
| **安装新版本** | `nvm install 22` | `mise install node@22` | 仅安装，不切换 |
| **列出已安装** | `nvm ls` | `mise ls node` | |

### 修改全局版本的正确姿势
如果你想把全局 Java 从 17 升级到 21：

1.  修改 Chezmoi 中的源文件 (推荐):
    ```bash
    chezmoi edit ~/.config/mise/config.toml
    # 将 java = "temurin-17" 改为 "temurin-21"
    ```
2.  应用更改:
    ```bash
    chezmoi apply
    # Mise 会自动检测并在后台安装 Java 21
    ```

---

## 4. Chezmoi 日常维护流程

### 修改配置 (Edit)
想修改 `.zshrc` 或 `.gitconfig` 时：
```bash
chezmoi edit ~/.zshrc
# 保存关闭后，运行：
chezmoi apply
```

### 添加新文件 (Add)
想把一个新的配置文件纳入管理 (例如 `~/.vimrc`)：
```bash
chezmoi add ~/.vimrc
```

### 同步到远程 (Push)
当你修改了配置，或者升级了 Mise 全局版本后，记得推送到 GitHub：
```bash
cd ~/.local/share/chezmoi
git add .
git commit -m "chore: update configs"
git push
```

### 从远程拉取 (Pull)
在另一台机器上获取最新配置：
```bash
chezmoi update
```

---

## 5. 软件包管理 (Homebrew)

本配置使用 `Brewfile` 管理系统软件。

*   **添加软件**: 编辑 `~/.local/share/chezmoi/Brewfile`。
*   **生效**: 
    *   等待下次 `chezmoi apply` (如果脚本包含自动运行逻辑)
    *   或者手动运行 `brew bundle --file=~/.local/share/chezmoi/Brewfile`

---

## 7. 模板变量管理

### 配置文件位置
- **交互式配置**: `.chezmoi.toml.tmpl` - 首次运行时会提示输入各种配置值
- **静态配置**: `~/.config/chezmoi/chezmoi.yaml` - 直接设置配置值，跳过交互

### 支持的模板变量

| 变量类别 | 变量名 | 默认值 | 说明 |
|---------|--------|--------|------|
| **Git** | `name` | "Dipsy" | Git 用户名 |
| | `email` | "your.email@example.com" | Git 邮箱 |
| **工具版本** | `versions.go` | "latest" | Go 版本 |
| | `versions.java` | "temurin-21" | Java 版本 |
| | `versions.node` | "lts" | Node.js 版本 |
| | `versions.python` | "3.11" | Python 版本 |
| | `versions.flutter` | "3.35.3" | Flutter 版本 |
| **AWS** | `aws.cn_region` | "cn-north-1" | AWS 中国区域 |
| | `aws.sg_region` | "ap-southeast-1" | AWS 新加坡区域 |
| | `aws.codeartifact_domain` | "nautilus" | CodeArtifact 域名 |
| **家居自动化** | `home.tailscale_path` | "" | Tailscale 路径，留空自动检测 |
| | `home.ssh_host` | "home-pc" | SSH 主机别名 |
| | `home.pc_ip` | "192.168.50.197" | 家用电脑 IP |
| **Shell** | `shell.enable_starship` | true | 启用 Starship 提示符 |
| | `shell.enable_zoxide` | true | 启用 Zoxide (智能 cd) |
| | `shell.enable_eza` | true | 启用 Eza (更好的 ls) |

## 🔧 PATH 自动管理

### 为什么不需要手动设置 PATH？

1. **永久设置**: `.zshrc` 模板中已包含 PATH 设置代码
2. **自动检查**: 每次启动 shell 时自动检查并添加 `~/.local/bin`
3. **一次设置**: 安装完成后重启终端，PATH 永久生效

### PATH 设置代码 (在 .zshrc 中)
```bash
# zsh path array automatically de-duplicates entries.
typeset -U path
path=("$HOME/.local/bin" $path)
```

### 如果 PATH 有问题
```bash
# 检查 PATH
echo $PATH | grep -o "$HOME/.local/bin"

# 手动重新加载配置
source ~/.zshrc

# 或重启终端
exec zsh
```

## 8. 常见问题 (FAQ)

*   **Q: `chezmoi` 命令找不到？**
    *   A: 确保使用了 `-b $HOME/.local/bin` 参数安装，并且 `~/.local/bin` 在你的 `PATH` 中。如果刚安装完，尝试重启终端或运行 `export PATH="$HOME/.local/bin:$PATH"`。

*   **Q: 安装时提示权限被拒绝？**
    *   A: 使用 `-b $HOME/.local/bin` 参数将 chezmoi 安装到用户目录，避免需要 sudo 权限。

*   **Q: Mise 切换版本没生效？**
    *   A: 检查是否开启了 `mise activate zsh` (在 `.zshrc` 中)。运行 `mise doctor` 查看诊断信息。

*   **Q: 如何在不同机器上使用不同的配置？**
    *   A: 编辑 `~/.config/chezmoi/chezmoi.yaml` 文件，或者删除该文件重新运行 `chezmoi init` 进行交互式配置。

*   **Q: 如何备份当前配置？**
    *   A: 安装脚本会自动备份到 `~/.dotfiles_backup_<时间戳>` 目录。你也可以手动备份重要配置文件。
