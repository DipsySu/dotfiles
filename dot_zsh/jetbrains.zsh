# JetBrains Toolbox 生成的命令行启动脚本（idea、pycharm 等）
for _jb in "$HOME/.local/share/JetBrains/Toolbox/scripts" \
           "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"; do
    [[ -d "$_jb" ]] && path+=("$_jb")
done
unset _jb
