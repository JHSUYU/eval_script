#!/bin/zsh

# 配置变量
LOCAL_SCRIPT="/Users/lizhenyu/IdeaProjects/eval_script/solr_scripts/upload_github.sh"
RECONFIGURE_SCRIPT="/Users/lizhenyu/IdeaProjects/eval_script/solr_scripts/reconfigure_solr.sh"
REMOTE_PATH="/opt/"
REMOTE_SCRIPT="/opt/upload_github.sh"
SERVERS=("ms1132.utah.cloudlab.us", "ms1101.utah.cloudlab.us")
USER="ZhenyuLi"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2}${1}${NC}"
}

# 检查本地脚本是否存在
if [ ! -f "$LOCAL_SCRIPT" ]; then
    print_message "错误: 本地脚本 $LOCAL_SCRIPT 不存在" "$RED"
    exit 1
fi

print_message "开始部署流程..." "$GREEN"

# 遍历所有服务器
for SERVER in "${SERVERS[@]}"; do
    print_message "\n处理服务器: $SERVER" "$YELLOW"

    # 步骤1: 复制脚本到远程服务器
    print_message "正在复制脚本到 $USER@$SERVER:$REMOTE_PATH ..." "$GREEN"
    if scp "$LOCAL_SCRIPT" "$USER@$SERVER:$REMOTE_PATH"; then
        print_message "✓ 文件复制成功" "$GREEN"
    else
        print_message "✗ 文件复制失败，跳过此服务器" "$RED"
        continue
    fi

    scp "$RECONFIGURE_SCRIPT" "$USER@$SERVER:$REMOTE_PATH"

    # 步骤2: SSH到远程服务器并执行脚本
    print_message "正在连接到 $SERVER 并执行脚本..." "$GREEN"
    ssh "$USER@$SERVER" << EOF
        # 确保脚本有执行权限
        chmod +x $REMOTE_SCRIPT

        # 执行脚本
        echo "开始执行 $REMOTE_SCRIPT"
        $REMOTE_SCRIPT

        # 检查执行结果
        if [ \$? -eq 0 ]; then
            echo "✓ 脚本执行成功"
        else
            echo "✗ 脚本执行失败，退出码: \$?"
        fi
EOF

    if [ $? -eq 0 ]; then
        print_message "✓ 服务器 $SERVER 处理完成" "$GREEN"
    else
        print_message "✗ 服务器 $SERVER 处理失败" "$RED"
    fi
done

print_message "\n所有操作完成！" "$GREEN"