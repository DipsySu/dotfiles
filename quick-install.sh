#!/bin/bash
# 一键安装脚本 - 自动处理 PATH 设置

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 开始 Dotfiles 一键安装...${NC}"

if [ "$(uname -s)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  未检测到 Xcode Command Line Tools。请在弹窗中完成安装后重新运行本脚本。${NC}"
    xcode-select --install || true
    exit 1
fi

# 1. 确保目录存在
mkdir -p "$HOME/.local/bin"

# 2. 临时设置 PATH (用于安装过程)
export PATH="$HOME/.local/bin:$PATH"

# 3. 安装 chezmoi 并初始化
echo -e "${GREEN}📦 安装 Chezmoi...${NC}"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply DipsySu

echo -e "${BLUE}🎉 安装完成！${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 重启终端或运行: exec zsh"
echo "2. 验证安装: brew --prefix && mise ls && eza --version && starship --version"
echo ""
echo -e "${GREEN}PATH 已永久设置，以后不需要手动配置！${NC}"
