# Dotfiles 使用指南 & 备忘录 (TIPS.md)

本文档记录了本套 Dotfiles 的架构逻辑、常用命令以及在新机器上的恢复流程。

## 1. 核心架构

*   **配置管理**: [Chezmoi](https://www.chezmoi.io/) - 负责同步 `.zshrc`, `.gitconfig` 以及 Mise 的全局配置。
*   **运行时管理**: [Mise](https://mise.jdx.dev/) - 替代 nvm, pyenv, rbenv。负责安装 Node, Python, Java, Go。
*   **包管理**: Homebrew - 负责安装 CLI 工具 (git, fzf, starship 等)。

---

## 2. 新机器初始化 (Bootstrap)

在全新的 macOS 或 WSL (Ubuntu) 上，只需执行以下步骤：

### 步骤 A: 一键安装
*(假设你已经将此仓库托管在 GitHub 上)*

```bash
# 1. 初始化并应用配置
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply <你的GitHub用户名>

# 2. (如果 Shell 没自动刷新) 重载配置
source ~/.zshrc
```

该命令会自动完成以下工作：
1.  安装 `chezmoi` 二进制文件。
2.  拉取你的 Dotfiles 仓库。
3.  将配置文件映射到 `~` 目录。
4.  自动运行 `run_once_install-packages.sh` 脚本，安装 Homebrew, Brew 软件, 和 Mise 运行时。

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

## 6. 常见问题 (FAQ)

*   **Q: `chezmoi` 命令找不到？**
    *   A: 确保 `~/.local/bin` 在你的 `PATH` 中。如果刚安装完，尝试重启终端。

*   **Q: Mise 切换版本没生效？**
    *   A: 检查是否开启了 `mise activate zsh` (在 `.zshrc` 中)。运行 `mise doctor` 查看诊断信息。
