#!/bin/bash
# 一键安装脚本 - 自动处理 PATH 设置

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 开始 Dotfiles 一键安装...${NC}"

# 1. 确保目录存在
mkdir -p "$HOME/.local/bin"

# 2. 临时设置 PATH (用于安装过程)
export PATH="$HOME/.local/bin:$PATH"

# 3. 安装 chezmoi 并初始化
echo -e "${GREEN}📦 安装 Chezmoi...${NC}"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" init --apply DipsySu

# 4. 确保 PATH 永久生效
echo -e "${GREEN}🔧 设置永久 PATH...${NC}"

# 检查当前 shell
if [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

# 添加 PATH 到 shell 配置 (如果还没有)
if [ -f "$SHELL_CONFIG" ] && ! grep -q '$HOME/.local/bin' "$SHELL_CONFIG"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
    echo -e "${GREEN}✅ 已添加 ~/.local/bin 到 $SHELL_CONFIG${NC}"
fi

# 5. 重新加载配置
echo -e "${GREEN}🔄 重新加载 shell 配置...${NC}"
if [ -f "$HOME/.zshrc" ]; then
    source "$HOME/.zshrc" 2>/dev/null || true
fi

echo -e "${BLUE}🎉 安装完成！${NC}"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "1. 重启终端或运行: exec zsh"
echo "2. 验证安装: eza --version && starship --version"
echo ""
echo -e "${GREEN}PATH 已永久设置，以后不需要手动配置！${NC}"