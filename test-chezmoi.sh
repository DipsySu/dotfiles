#!/bin/bash
# 测试 chezmoi 配置的脚本

echo "🔍 测试 Chezmoi 配置..."

# 检查 chezmoi 是否可用
if ! command -v chezmoi &> /dev/null; then
    echo "❌ chezmoi 未找到"
    exit 1
fi

echo "✅ chezmoi 已安装: $(chezmoi --version)"

# 检查配置文件
echo "📋 检查配置文件..."
chezmoi data

# 检查模板渲染
echo "🔧 测试模板渲染..."
if chezmoi execute-template < /dev/null; then
    echo "✅ 模板语法正确"
else
    echo "❌ 模板语法错误"
    exit 1
fi

# 检查 run_once 脚本
echo "📜 检查 run_once 脚本..."
if [ -f "$HOME/.local/share/chezmoi/run_once_install-packages.sh.tmpl" ]; then
    echo "✅ run_once 脚本存在"
    
    # 尝试渲染脚本
    if chezmoi cat run_once_install-packages.sh > /dev/null; then
        echo "✅ run_once 脚本可以正确渲染"
    else
        echo "❌ run_once 脚本渲染失败"
        exit 1
    fi
else
    echo "❌ run_once 脚本不存在"
    exit 1
fi

echo "🎉 所有检查通过！"