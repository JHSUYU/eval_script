#!/bin/bash

# 定义节点列表
NODES=("node2" "node3")

# 定义要杀掉的进程名
PROCESS_NAME="DataNode"

# 函数：在指定节点上杀掉DataNode进程
kill_datanode_on_node() {
    local node=$1
    echo "正在连接到 $node..."

    # SSH到节点并执行命令
    ssh $node << EOF
        echo "在 $node 上查找 $PROCESS_NAME 进程..."

        # 使用jps查找DataNode进程ID
        DATANODE_PID=\$(jps | grep $PROCESS_NAME | awk '{print \$1}')

        if [ -n "\$DATANODE_PID" ]; then
            echo "找到 $PROCESS_NAME 进程，PID: \$DATANODE_PID"
            echo "正在杀掉 $PROCESS_NAME 进程..."
            kill -9 \$DATANODE_PID

            # 验证进程是否已被杀掉
            sleep 2
            REMAINING_PID=\$(jps | grep $PROCESS_NAME | awk '{print \$1}')
            if [ -z "\$REMAINING_PID" ]; then
                echo "✓ $PROCESS_NAME 进程已在 $node 上成功杀掉"
            else
                echo "✗ $PROCESS_NAME 进程在 $node 上仍在运行"
            fi
        else
            echo "在 $node 上未找到 $PROCESS_NAME 进程"
        fi
EOF

    # 检查SSH连接是否成功
    if [ $? -eq 0 ]; then
        echo "✓ 已完成对 $node 的操作"
    else
        echo "✗ 连接到 $node 失败"
    fi
    echo "----------------------------------------"
}

# 主执行逻辑
echo "开始杀掉 $PROCESS_NAME 进程..."
echo "========================================"

# 遍历所有节点
for node in "${NODES[@]}"; do
    kill_datanode_on_node $node
done

echo "所有操作已完成！"

# 可选：显示最终状态
echo "========================================"
echo "最终状态检查："
for node in "${NODES[@]}"; do
    echo "检查 $node 上的进程状态..."
    ssh $node "jps | grep -E '(DataNode|Jps)' || echo '没有找到相关进程'"
done