# Dotfiles

用 chezmoi 管理 macOS、Linux 和 WSL 的 shell、Git、mise 配置。机器差异放在私有 `local.toml`，软件安装与配置同步分别控制。

## 初始化

已有 chezmoi 时：

```sh
chezmoi init DipsySu
chezmoi diff
chezmoi apply
```

新机器可先下载并检查安装脚本，再执行：

```sh
curl --fail --show-error --location --proto '=https' \
  https://raw.githubusercontent.com/DipsySu/dotfiles/master/quick-install.sh \
  -o /tmp/dotfiles-quick-install.sh && bash /tmp/dotfiles-quick-install.sh
```

脚本会检查 macOS Command Line Tools、下载安装 chezmoi，再初始化配置。安装下载失败时返回错误，不报告安装成功。

需要跳过提问时，先把仓库中的 [local.toml.example](local.toml.example) 复制为 `~/.config/chezmoi/local.toml`，填写个人信息并设为 `chmod 600`。示例包含所有配置项；文件顶层没有 `[data]`。

```sh
mkdir -p ~/.config/chezmoi
cp ~/.local/share/chezmoi/local.toml.example ~/.config/chezmoi/local.toml
chmod 600 ~/.config/chezmoi/local.toml
# 编辑 local.toml 后：
chezmoi init
chezmoi diff
chezmoi apply
```

不要把私有邮箱、地址、凭据写回仓库示例。旧的 `profile.yaml` 没有加载逻辑，已由这个可实际使用的示例替代。

## 配置与安装的边界

| 操作 | 行为 |
| --- | --- |
| `chezmoi init` | 从私有 `local.toml` 和交互输入生成 chezmoi 配置 |
| `chezmoi apply` | 应用受管配置，并执行符合条件的安装脚本 |
| `bootstrap_packages = false` | 跳过整套 Homebrew 和 mise 首次安装任务，适合已有机器 |
| 首次安装任务启用 | Homebrew `bundle --no-upgrade` 补齐缺失包；mise 安装声明的运行时 |
| 原生 CLI 检查 | 每次 apply 检查入口；只安装缺失工具，不主动升级已有工具 |
| Yazi 插件检查 | 缺少 `ya` 时跳过；清单变化或插件缺少 `main.lua` 时重试安装 |

首次配置备份由 `run_once_before_00-backup-config.sh.tmpl` 在覆盖文件**之前**执行，保留相对目录结构并限制备份权限；失败会阻止后续 apply。它不等同于持续备份，重要批量更新前仍应自行备份。脚本执行记录按 chezmoi 的 run_once 规则保存。

`latest`、`lts`、`3.11` 等是版本范围。同步同一配置不会强制两台机器使用完全相同的已安装版本，也不会在关闭 bootstrap 后后台安装所有运行时。需要相同版本时，在各自 `local.toml` 中写完整版本号，然后显式安装。

mise 2026.8.4 及以上写入 `upgrade.auto_prune = false`，保留升级前的旧运行时；模板通过离线 `--version` 判断兼容性。旧版不写入不支持的字段，应使用显式 `mise install <工具>@<版本>` 补装，避免执行会删除旧版本的 `mise upgrade`。已有延迟删除计划需要另外检查；关闭自动删除不撤回过去已安排的删除。

## 机器差异

```toml
# local.toml 顶层
bootstrap_packages = false
enable_android = false
disabled_mise_tools = ["rust"]

[extra_mise_tools]
"npm:@google/gemini-cli" = "latest"
```

`false`、空字符串、空数组均能覆盖旧值。`extra_mise_tools` 整表替换；空表表示不添加额外工具。`disabled_mise_tools` 只取消声明，不卸载已安装版本。关闭 Android 会跳过其 shell 模块和安装项；已有机器的旧模块应先备份再手动移出加载目录。

- `~/.zshrc.local` 最后加载，适合 iTerm2 Shell Integration、快捷键、本机路径及代理。
- `~/.gitconfig.local` 最后 include，适合凭据 helper、本机 Git 代理等。
- 上述私有文件不会被 apply 覆盖。
- Git 默认使用项目自己的 hooks；`~/.git-hooks/commit-msg` 仅为可选的署名过滤脚本，不再通过全局 `core.hooksPath` 接管项目。它保留人类合作者署名。
- Zinit 优先加载 Homebrew 版本，其次读取已有的用户目录版本；缺失时 shell 启动不再自动 clone 管理器。显式执行 `brew install zinit` 可补装。

## 原生 CLI 与 Grok 代理

| 工具 | 入口 |
| --- | --- |
| Codex CLI | `~/.local/bin/codex` |
| Claude Code | `~/.local/bin/claude` |
| Antigravity CLI | `~/.local/bin/agy` |
| Grok Build | `~/.grok/bin/grok`、`~/.grok/bin/agent`，并链接到 `~/.local/bin` |

实现位于 `scripts/ensure-ai-clis.sh`。缺失工具使用官方安装器；已有工具不升级。缺失或损坏的 Grok 软链接可以修复，有效用户入口保留。安装不包含登录或模型请求。`agy` 是 CLI，Antigravity IDE 需单独安装。

安装器运行时保留 shell 配置和已有 Claude settings；恢复失败时保留备份并输出路径。Antigravity 安装器的 setup 使用 `--skip-path --skip-aliases`，布局不符合预期时停止安装。

`dot_zsh/ai-tools.zsh` 在 mise 更新 PATH 后恢复本地原生入口优先级。Grok 默认检查 `127.0.0.1:7897`，端口监听时只为本次进程设置代理；未监听时保留调用者设置。

```zsh
GROK_PROXY_PORT=7890 grok login
codex --version
claude --version
agy --version
grok --version
```

缺失安装可使用本机 `local.toml` 中的脚本环境选项：

```toml
[scriptEnv]
CODEX_INSTALLER_USE_RELEASES_OPENAI_COM = "0"
```

WSL 启动默认不设置代理。需要时手动执行 `proxy_on` / `proxy_off`；可在 `.zshrc.local` 设置 `WSL_PROXY_PORT=7890` 后调用 `proxy_on`。Git 的独立代理也应写在私有 `.gitconfig.local`。

## 数据保护与空间检查

`mac_clean` 和 `dprune` 都只显示空间使用情况，不删除缓存、容器、卷或快照。清理前应核对具体目录、软链接和引用关系，再决定要删除什么。

**`~/.local/share/mise/http-tarballs` 可能存放正在使用的 SDK。** HTTP 安装后端会让 `installs/<工具>/<版本>` 指向这里。Flutter 就可能通过这种软链接使用解压后的文件；清空目录会直接破坏安装。不能仅凭目录名或“缓存”分类判断能否删除，也不能仅凭 `installs` 下的版本目录仍在就认定工具完好。检查时应解析链接目标并运行实际可执行文件。参见 [mise HTTP 后端说明](https://mise.jdx.dev/dev-tools/backends/http.html)。

## 维护与验证

```sh
cd ~/.local/share/chezmoi
bash test-chezmoi.sh
# 检查 diff 后按需提交
# 在另一台机器获取并应用：
chezmoi update
```

测试要求 `chezmoi`、`git`、`bash`、`zsh` 和 Python 3.11+；缺少 Python 时会明确失败，不跳过 TOML 语义验证。测试覆盖 macOS ARM / Intel、Linux / WSL 模板，及安装失败、备份顺序、Git hooks、AWS 状态提交、Tailscale 状态、路径注入和插件完整性。所有安装和失败场景使用临时目录与 mock，不调用模型，也不清理真实数据。

更多日常操作见 [TIPS.md](TIPS.md)。

## 许可证

MIT License。
