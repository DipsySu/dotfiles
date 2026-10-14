# Dotfiles 使用备忘

## 配置来源

- 仓库 `.chezmoi.toml.tmpl` 定义配置结构。
- 私有 `~/.config/chezmoi/local.toml` 保存机器选项，完整格式见 `local.toml.example`。
- `chezmoi init` 读取私有文件，生成 `~/.config/chezmoi/chezmoi.toml`。
- `chezmoi apply` 把模板渲染到目标文件。

不要直接改生成后的 mise 全局配置来保存长期设置：下一次 apply 会按模板覆盖。应修改 `local.toml`，再 `chezmoi init`、查看 diff、apply。

## 机器初始化

已有 chezmoi 时运行 `chezmoi init DipsySu`。完整的下载和初次安装步骤见 README。

要避免提问，先填写完整 `local.toml.example` 并保存为私有配置；仅填写部分字段时，缺少的字段仍可能提问。

```sh
chmod 600 ~/.config/chezmoi/local.toml
chezmoi init
chezmoi diff
chezmoi apply
```

已有机器通常设 `bootstrap_packages = false`；它只跳过 Homebrew / mise 的整套初始化，原生 CLI 和 Yazi 的缺失检查仍会执行。

## mise 运行时

| 目的 | 命令 | 是否写配置 |
| --- | --- | --- |
| 当前 shell 临时选择 | `mise shell node@24` | 否，需要 shell activation |
| 单次命令选择版本 | `mise exec node@24 -- node --version` | 否 |
| 项目选择版本 | `mise use node@24` | 是，在项目目录运行 |
| 全局选择版本 | `mise use -g node@24` | 是；长期设置应同步到私有 `local.toml` |
| 安装指定版本 | `mise install node@24` | 不改版本声明 |

`mise use` 会写配置，不是仅对当前窗口临时生效。可参见 [mise use 文档](https://mise.jdx.dev/cli/use.html)。版本缺失时，上述选择命令可能触发安装。

例如修改 Java 的长期声明：

```toml
# ~/.config/chezmoi/local.toml
[versions]
java = "temurin-21"
```

```sh
chezmoi init
chezmoi diff
chezmoi apply
# 如果需要补装，请显式运行：
mise install java@temurin-21
```

普通 apply 不保证后台安装新声明的运行时。`latest` / `lts` / `3.11` 也不保证跨机器解析成同一版本；需要一致时填写完整版本号。

### 旧版本与 http-tarballs

mise 2026.8.4 及以上使用 `upgrade.auto_prune = false`，避免升级时安排旧版本自动删除。模板离线读取 `mise --version`，旧版不写入未知字段。旧版没有这项保留设置，应使用 `mise install <工具>@<版本>` 补装，避免运行 `mise upgrade`。升级 mise 管理器后再次 apply，模板会自动启用受支持的保护设置。过去已经存在的延迟删除计划不会因设置而取消，维护前应检查 mise 状态目录中的 `tool-purgatory.json`；不要把普通查询误认为绝无副作用。

`http-tarballs` 是 HTTP 后端的共享解压存储，可能是运行时的实际安装目录。Flutter 的 `installs/flutter/<版本>` 可以是指向它的软链接。不能直接整目录删除；清理审核应核对所有安装的真实目标并验证工具可运行。详见 [官方 HTTP 后端文档](https://mise.jdx.dev/dev-tools/backends/http.html)。

## Homebrew 与 Zinit

仓库清单是 `~/.local/share/chezmoi/dot_Brewfile`，apply 后的目标是 `~/.Brewfile`。已有机器增加包后，可显式补装：

```sh
chezmoi apply
brew bundle --no-upgrade --file="$HOME/.Brewfile"
```

这个显式命令使用完整 Brewfile。关闭 Android 的机器应只安装所需包，或使用初始化脚本中的 Android 过滤逻辑，避免把已选择跳过的软件又装回来。

Zinit 管理器缺失时，终端启动只跳过加载。需要时运行 `brew install zinit`。插件仍按 Zinit 配置加载。

## Git、代理和本机定制

`~/.gitconfig.local` 最后 include，`~/.zshrc.local` 最后 source。私有凭据 helper、iTerm2 集成和本机路径放在这些文件中；已有内容不会被 apply 覆盖。

全局不再设置 `core.hooksPath`，项目的普通 hooks 和 worktree hooks 按 Git 的规则执行。已有 `~/.git-hooks` 文件保留，但不再自动接管每个项目。若项目确实需要调用可选的 `~/.git-hooks/commit-msg` 署名过滤器，应从项目自己的 hook 明确调用；该过滤器不转调其他 hook，不删除人类合作者 trailer。使用 LFS 的项目应自行确认项目中的 `git lfs install --local` hooks 已配置。

WSL 不自动启用 `127.0.0.1:7897`。需要本地代理时：

```zsh
WSL_PROXY_PORT=7890 proxy_on
proxy_off
```

如需 Git 独立代理，写入私有 `.gitconfig.local`：

```gitconfig
[http]
    proxy = http://127.0.0.1:7890
```

Grok 的代理只在本地端口监听时对该进程启用，可以用 `GROK_PROXY_PORT=7890 grok login` 临时选择端口。

## 常用辅助命令

- `mac_clean`：预览空间，完全不执行删除。
- `dprune`：显示 Docker 空间明细，不删除容器、镜像或数据卷。
- `mac_check`：按系统报告的实际内存页大小计算占用。
- `gpullall`：并行拉取当前目录下的 Git 仓库；支持含特殊字符的目录和 worktree，拉取失败返回非零。
- AWS profile 切换函数：获取凭据等步骤全部成功后才切换环境，失败保留原环境。
- 家庭网络函数：只在 Tailscale JSON 状态为 `Running` 时继续；启动中有限重试，未登录时明确失败。

## 同步与恢复

```sh
cd ~/.local/share/chezmoi
bash test-chezmoi.sh
git diff
# 按需 git add / commit / push
```

另一台机器使用 `chezmoi update` 拉取并应用。跨平台测试使用临时目录、mock 安装器和固定平台数据，不会清理真实数据。

覆盖前备份由 `run_once_before_00-backup-config.sh.tmpl` 负责，日志会打印保存位置，目录保留原来的相对结构并限制为私有访问。它按 run_once 记录执行，不是每次 apply 的持续备份。重要批量变更前，应额外备份目标配置和机器私有文件。

恢复时先查看备份内容，只还原需要的文件，再将需要长期保留的设置写回模板或私有 `local.toml` / `.zshrc.local` / `.gitconfig.local`。不要用恢复配置的操作删除运行时、项目、应用数据或 Docker 卷。
