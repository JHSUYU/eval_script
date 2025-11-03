#!/bin/zsh

# 配置变量
LOCAL_SCRIPT="/Users/lizhenyu/IdeaProjects/eval_script/solr_scripts/upload_github.sh"
RECONFIGURE_SCRIPT="/Users/lizhenyu/IdeaProjects/eval_script/solr_scripts/reconfigure_solr.sh"
REMOTE_PATH="/opt/"
REMOTE_SCRIPT="/opt/upload_github.sh"
SERVERS=("clnode311.clemson.cloudlab.us" "clnode314.clemson.cloudlab.us")
USER="ZhenyuLi"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_message "开始并行部署流程..." "$GREEN"
print_message "目标服务器: ${#SERVERS[@]} 个" "$BLUE"

# 处理单个服务器的函数
process_server() {
    local SERVER=$1

    # 步骤1: 复制脚本到远程服务器
    echo "[$SERVER] 正在复制脚本..."
    if ! scp "$LOCAL_SCRIPT" "$USER@$SERVER:$REMOTE_PATH" 2>/dev/null; then
        echo "[$SERVER] ✗ upload_github.sh 复制失败"
        return 1
    fi
    echo "[$SERVER] ✓ upload_github.sh 复制成功"

    if ! scp "$RECONFIGURE_SCRIPT" "$USER@$SERVER:$REMOTE_PATH" 2>/dev/null; then
        echo "[$SERVER] ✗ reconfigure_solr.sh 复制失败"
        return 1
    fi
    echo "[$SERVER] ✓ reconfigure_solr.sh 复制成功"

    # 步骤2: SSH到远程服务器并执行脚本
    echo "[$SERVER] 正在执行脚本..."
    ssh "$USER@$SERVER" << EOF
        # 确保脚本有执行权限
        chmod +x $REMOTE_SCRIPT
        chmod +x /opt/reconfigure_solr.sh

        # 执行脚本
        echo "开始执行 $REMOTE_SCRIPT"
        $REMOTE_SCRIPT

        # 检查执行结果
        if [ \$? -eq 0 ]; then
            echo "✓ 脚本执行成功"
        else
            echo "✗ 脚本执行失败，退出码: \$?"
            exit 1
        fi
EOF

    if [ $? -eq 0 ]; then
        echo "[$SERVER] ✓ 处理完成"
        return 0
    else
        echo "[$SERVER] ✗ 处理失败"
        return 1
    fi
}

# 存储后台任务的PID
typeset -a PIDS=()

# 并行启动所有服务器的处理
print_message "\n启动并行任务..." "$YELLOW"
for SERVER in "${SERVERS[@]}"; do
    {
        process_server "$SERVER"
    } &
    PIDS+=($!)
    print_message "已启动: $SERVER (PID: $!)" "$BLUE"
done

# 等待所有后台任务完成并收集结果
print_message "\n等待所有任务完成..." "$YELLOW"

# 初始化结果数组
typeset -a SUCCESS_SERVERS=()
typeset -a FAILED_SERVERS=()

# 等待每个进程并检查结果
for i in {1..${#SERVERS[@]}}; do
    wait ${PIDS[$i]}
    if [ $? -eq 0 ]; then
        SUCCESS_SERVERS+=(${SERVERS[$i]})
    else
        FAILED_SERVERS+=(${SERVERS[$i]})
    fi
done

# 显示结果摘要
print_message "\n========== 部署结果 ==========" "$YELLOW"

if [ ${#SUCCESS_SERVERS[@]} -gt 0 ]; then
    print_message "成功 (${#SUCCESS_SERVERS[@]}):" "$GREEN"
    for SERVER in "${SUCCESS_SERVERS[@]}"; do
        print_message "  ✓ $SERVER" "$GREEN"
    done
fi

if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    print_message "失败 (${#FAILED_SERVERS[@]}):" "$RED"
    for SERVER in "${FAILED_SERVERS[@]}"; do
        print_message "  ✗ $SERVER" "$RED"
    done
fi

print_message "==============================" "$YELLOW"

# 根据结果设置退出码
if [ ${#FAILED_SERVERS[@]} -eq 0 ]; then
    print_message "\n所有操作成功完成！" "$GREEN"
    exit 0
else
    print_message "\n部分操作失败，请检查失败的服务器" "$RED"
    exit 1
fi