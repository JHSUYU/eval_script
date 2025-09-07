#!/bin/bash

# HDFS故障注入脚本 - 随机选择单个节点kill DataNode
# 用于测试HDFS集群的容错能力

# ========== 配置 ==========
SERVERS=(
    "10.10.1.1"  # node0 - NameNode + DataNode
    "10.10.1.2"  # node1 - DataNode
    "10.10.1.3"  # node2 - DataNode
    "10.10.1.4"  # node3 - DataNode
    "10.10.1.5"  # node4 - DataNode
)

# 配置参数
SSH_USER="ZhenyuLi"
NAMENODE_SERVER="${SERVERS[0]}"  # node0作为NameNode
DATANODE_KILL_INTERVAL=10        # 每10秒kill一次DataNode
DATANODE_RESTART_DELAY=5         # kill后等待5秒再重启
NAMENODE_KILL_TIME=60            # 在60秒时kill NameNode
HADOOP_HOME="/opt/hadoop"        # Hadoop安装目录

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ========== 函数定义 ==========

# 打印带时间戳的日志
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $level in
        INFO)
            echo -e "${GREEN}[${timestamp}]${NC} [INFO] $message"
            ;;
        WARN)
            echo -e "${YELLOW}[${timestamp}]${NC} [WARN] $message"
            ;;
        ERROR)
            echo -e "${RED}[${timestamp}]${NC} [ERROR] $message"
            ;;
        ACTION)
            echo -e "${BLUE}[${timestamp}]${NC} [ACTION] $message"
            ;;
        RANDOM)
            echo -e "${MAGENTA}[${timestamp}]${NC} [RANDOM] $message"
            ;;
    esac
}

# 获取进程PID
get_process_pid() {
    local server=$1
    local process_name=$2

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "jps | grep '$process_name' | awk '{print \$1}' | head -1"
}

# Kill进程
kill_process() {
    local server=$1
    local process_name=$2

    local pid=$(get_process_pid "$server" "$process_name")

    if [ -z "$pid" ]; then
        log WARN "No $process_name process found on $server"
        return 1
    fi

    log ACTION "Killing $process_name (PID: $pid) on $server"

    # 先尝试正常kill
    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "kill $pid"

    sleep 2

    # 检查进程是否还在运行
    local check_pid=$(get_process_pid "$server" "$process_name")
    if [ ! -z "$check_pid" ]; then
        log WARN "$process_name still running, using kill -9"
        ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
            "kill -9 $pid"
    fi

    log INFO "$process_name killed on $server"
    return 0
}

# 启动DataNode
start_datanode() {
    local server=$1

    log ACTION "Starting DataNode on $server"

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null << EOF
        export HADOOP_HOME=$HADOOP_HOME
        export PATH=\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH

        # 检查DataNode是否已经在运行
        if jps | grep -q DataNode; then
            echo "DataNode already running"
        else
            # 启动DataNode
            \$HADOOP_HOME/bin/hdfs --daemon start datanode
            sleep 5

        fi
EOF

    if [ $? -eq 0 ]; then
        log INFO "DataNode started successfully on $server"
    else
        log ERROR "Failed to start DataNode on $server"
    fi
}

# 启动NameNode
start_namenode() {
    local server=$1

    log ACTION "Starting NameNode on $server"

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null << EOF
        export HADOOP_HOME=$HADOOP_HOME
        export PATH=\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH

        # 检查NameNode是否已经在运行
        if jps | grep -q NameNode; then
            echo "NameNode already running"
        else
            # 启动NameNode
            \$HADOOP_HOME/bin/hdfs --daemon start namenode
            sleep 3

            # 验证启动
            if jps | grep -q NameNode; then
                echo "NameNode started successfully"
            else
                echo "Failed to start NameNode"
                exit 1
            fi
        fi
EOF

    if [ $? -eq 0 ]; then
        log INFO "NameNode started successfully on $server"
    else
        log ERROR "Failed to start NameNode on $server"
    fi
}

# 随机选择一个节点索引（0-4）
select_random_node() {
    # 只从前5个节点中选择 (node0-node4)
    local random_index=$((RANDOM % 5))
    echo $random_index
}

# Kill和重启随机选择的DataNode
kill_and_restart_random_datanode() {
    # 随机选择一个节点
    local node_index=$(select_random_node)
    local server=${SERVERS[$node_index]}

    log RANDOM "🎲 Selected node$node_index ($server) for fault injection"

    # Kill DataNode
    if kill_process "$server" "DataNode"; then
        # 等待指定时间
        log INFO "Waiting ${DATANODE_RESTART_DELAY} seconds before restarting..."
        sleep $DATANODE_RESTART_DELAY

        # 重启DataNode
        start_datanode "$server"
    else
        log WARN "DataNode not running on node$node_index ($server), skipping..."
    fi

    # 返回被选中的节点索引用于统计
    echo $node_index
}

# 显示集群状态
show_cluster_status() {
    log INFO "Current HDFS Cluster Status:"
    echo "----------------------------------------"
    printf "%-8s %-15s %-12s %-12s\n" "Node" "Server" "NameNode" "DataNode"
    echo "----------------------------------------"

    for i in "${!SERVERS[@]}"; do
        server=${SERVERS[$i]}
        nn_pid=$(get_process_pid "$server" "NameNode")
        dn_pid=$(get_process_pid "$server" "DataNode")

        nn_status="-"
        dn_status="✗ Down"

        [ ! -z "$nn_pid" ] && nn_status="✓ PID:$nn_pid"
        [ ! -z "$dn_pid" ] && dn_status="✓ PID:$dn_pid"

        # 根据DataNode状态设置颜色
        if [ ! -z "$dn_pid" ]; then
            printf "node%-4d %-15s %-12s ${GREEN}%-12s${NC}\n" "$i" "$server" "$nn_status" "$dn_status"
        else
            printf "node%-4d %-15s %-12s ${RED}%-12s${NC}\n" "$i" "$server" "$nn_status" "$dn_status"
        fi
    done
    echo "----------------------------------------"
}

# 显示统计信息
show_statistics() {
    local elapsed=$1
    echo ""
    echo "========== Fault Injection Statistics =========="
    echo "Elapsed Time: ${elapsed}s"
    echo "Total Cycles: $CYCLE_COUNT"
    echo "Total DataNode Failures: $DATANODE_FAILURES"
    echo "NameNode Killed: $NAMENODE_KILLED"

    echo ""
    echo "Failures per Node (node0-node4):"
    for i in {0..4}; do
        local percentage=0
        if [ $DATANODE_FAILURES -gt 0 ]; then
            percentage=$((NODE_FAILURES[$i] * 100 / DATANODE_FAILURES))
        fi
        printf "  node%-2d (%-15s): %3d times (%3d%%)\n" "$i" "${SERVERS[$i]}" "${NODE_FAILURES[$i]}" "$percentage"
    done
    echo "================================================"
}

# ========== 主程序 ==========
main() {
    log INFO "Starting HDFS Random Fault Injection Script"
    log INFO "Configuration:"
    log INFO "  - Mode: Random single node selection (node0-node4)"
    log INFO "  - DataNode kill interval: ${DATANODE_KILL_INTERVAL}s"
    log INFO "  - DataNode restart delay: ${DATANODE_RESTART_DELAY}s"
    log INFO "  - NameNode kill time: ${NAMENODE_KILL_TIME}s"
    log INFO "  - Servers: ${SERVERS[@]}"
    echo ""

    # 初始化统计变量
    CYCLE_COUNT=0
    DATANODE_FAILURES=0
    declare -a NODE_FAILURES
    for i in {0..4}; do
        NODE_FAILURES[$i]=0
    done

    # 显示初始集群状态
    show_cluster_status
    echo ""

    # 记录开始时间
    START_TIME=$(date +%s)
    NAMENODE_KILLED=false

    log INFO "Starting random fault injection cycles..."
    log INFO "Press Ctrl+C to stop"
    echo ""

    while true; do
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))

        # 增加循环计数
        CYCLE_COUNT=$((CYCLE_COUNT + 1))

        echo ""
        log INFO "=== Cycle #$CYCLE_COUNT (Elapsed: ${ELAPSED}s) ==="

        # 检查是否到了kill NameNode的时间
        if [ $ELAPSED -ge $NAMENODE_KILL_TIME ] && [ "$NAMENODE_KILLED" = false ]; then
            log WARN "⚠️  Time to kill NameNode! (${ELAPSED}s >= ${NAMENODE_KILL_TIME}s)"
            kill_process "$NAMENODE_SERVER" "NameNode"
            NAMENODE_KILLED=true

            # 可选：在一定时间后重启NameNode
            # log INFO "Waiting 10 seconds before restarting NameNode..."
            # sleep 10
            # start_namenode "$NAMENODE_SERVER"
        fi

        # 随机选择并处理一个DataNode
        selected_node=$(kill_and_restart_random_datanode)

        # 更新统计
        if [ ! -z "$selected_node" ]; then
            NODE_FAILURES[$selected_node]=$((NODE_FAILURES[$selected_node] + 1))
            DATANODE_FAILURES=$((DATANODE_FAILURES + 1))
        fi

        # 显示当前集群状态
        echo ""
        show_cluster_status

        # 每5个周期显示一次统计信息
        if [ $((CYCLE_COUNT % 5)) -eq 0 ]; then
            show_statistics $ELAPSED
        fi

        # 等待下一个周期
        echo ""
        log INFO "Waiting ${DATANODE_KILL_INTERVAL} seconds for next cycle..."
        sleep $DATANODE_KILL_INTERVAL
    done
}

# 清理函数 - 在脚本退出时执行
cleanup() {
    echo ""
    log WARN "Script interrupted. Cleaning up..."

    # 显示最终统计
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    show_statistics $ELAPSED

    # 可选：重启所有停止的服务
    read -p "Do you want to restart all stopped services? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log INFO "Restarting all services..."

        # 重启NameNode（如果被kill了）
        if [ "$NAMENODE_KILLED" = true ]; then
            start_namenode "$NAMENODE_SERVER"
        fi

        # 检查并重启所有DataNode
        for i in {0..4}; do
            server=${SERVERS[$i]}
            log INFO "Checking DataNode on node$i ($server)"

            # 检查DataNode是否在运行
            dn_pid=$(get_process_pid "$server" "DataNode")
            if [ -z "$dn_pid" ]; then
                start_datanode "$server"
            else
                log INFO "DataNode already running on node$i"
            fi
        done

        echo ""
        log INFO "All services checked and restarted if needed"
        show_cluster_status
    fi

    log INFO "Fault injection script terminated"
    exit 0
}

# 捕获Ctrl+C信号
trap cleanup SIGINT SIGTERM

# 参数检查
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    echo "Usage: $0 [options]"
    echo ""
    echo "This script performs random fault injection on HDFS cluster by:"
    echo "  1. Randomly selecting ONE node from node0-node4 every ${DATANODE_KILL_INTERVAL}s"
    echo "  2. Killing the DataNode on the selected node"
    echo "  3. Waiting ${DATANODE_RESTART_DELAY}s then restarting the DataNode"
    echo "  4. Killing NameNode at ${NAMENODE_KILL_TIME}s"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --status       Show current cluster status and exit"
    exit 0
fi

if [ "$1" == "--status" ]; then
    show_cluster_status
    exit 0
fi

# 运行主程序
main