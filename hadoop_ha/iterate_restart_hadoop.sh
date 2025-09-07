#!/bin/bash

# Hadoop相关目录
HADOOP_HOME="/opt/hadoop"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
HDFS_CMD="$HADOOP_HOME/bin/hdfs"
HADOOP_CMD="$HADOOP_HOME/bin/hadoop"

# 集群节点配置
CLUSTER_NODES=("ms1205.utah.cloudlab.us" "ms1114.utah.cloudlab.us" "ms1136.utah.cloudlab.us" "ms1116.utah.cloudlab.us" "ms1028.utah.cloudlab.us")
USER="ZhenyuLi"  # 替换为你的用户名

# HA 配置
NAMENODE1="${CLUSTER_NODES[0]}"  # 主 NameNode
NAMENODE2="${CLUSTER_NODES[1]}"  # 备 NameNode
JOURNALNODE_NODES=("${CLUSTER_NODES[0]}" "${CLUSTER_NODES[1]}" "${CLUSTER_NODES[2]}")  # Journal Node 节点
ZOOKEEPER_NODES=("${CLUSTER_NODES[0]}" "${CLUSTER_NODES[1]}" "${CLUSTER_NODES[2]}")  # ZooKeeper 节点

echo "=== Hadoop HA集群完全重置脚本 ==="
echo "Hadoop主目录: $HADOOP_HOME"
echo "Hadoop配置目录: $HADOOP_CONF_DIR"
echo "集群节点: ${CLUSTER_NODES[*]}"
echo "主 NameNode: $NAMENODE1"
echo "备 NameNode: $NAMENODE2"
echo "Journal Node 节点: ${JOURNALNODE_NODES[*]}"
echo "ZooKeeper 节点: ${ZOOKEEPER_NODES[*]}"

# 步骤1: 停止所有Hadoop服务
echo "====================================="
echo "步骤1: 停止所有Hadoop服务"
echo "====================================="

# 停止YARN服务
echo "正在停止YARN服务..."
ssh "$USER@$NAMENODE1" "bash -s" << EOF
    if [ -f "$HADOOP_HOME/sbin/stop-yarn.sh" ]; then
        "$HADOOP_HOME/sbin/stop-yarn.sh"
    fi
EOF

# 停止ZKFC (ZooKeeper Failover Controller)
echo "正在停止ZKFC服务..."
for namenode in "$NAMENODE1" "$NAMENODE2"; do
    echo "停止 $namenode 上的ZKFC..."
    ssh "$USER@$namenode" "$HDFS_CMD --daemon stop zkfc"
done

# 停止NameNode服务
echo "正在停止NameNode服务..."
for namenode in "$NAMENODE1" "$NAMENODE2"; do
    echo "停止 $namenode 上的NameNode..."
    ssh "$USER@$namenode" "$HDFS_CMD --daemon stop namenode"
done

# 停止DataNode服务
echo "正在停止DataNode服务..."
for node in "${CLUSTER_NODES[@]}"; do
    echo "停止 $node 上的DataNode..."
    ssh "$USER@$node" "$HDFS_CMD --daemon stop datanode"
done

# 停止Journal Node服务
echo "正在停止Journal Node服务..."
for jn_node in "${JOURNALNODE_NODES[@]}"; do
    echo "停止 $jn_node 上的JournalNode..."
    ssh "$USER@$jn_node" "$HDFS_CMD --daemon stop journalnode"
done

# 等待服务完全停止
echo "等待所有服务完全停止..."
sleep 15

# 步骤2: 在所有节点上执行清理操作
echo "====================================="
echo "步骤2: 清理所有节点的Hadoop数据"
echo "====================================="

for node in "${CLUSTER_NODES[@]}"; do
    echo "正在处理节点: $node"

    ssh "$USER@$node" "bash -s" << 'EOF'
    HOSTNAME=$(hostname)
    echo "[$HOSTNAME] 开始清理Hadoop数据..."

    # Hadoop相关目录
    HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}
    HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-"$HADOOP_HOME/etc/hadoop"}

    # 确保所有相关进程已停止
    for PROC in "namenode" "datanode" "secondarynamenode" "resourcemanager" "nodemanager" "journalnode" "zkfc"; do
        if pgrep -f "$PROC" > /dev/null; then
            echo "[$HOSTNAME] 正在停止残留的$PROC进程..."
            pkill -f "$PROC"
            sleep 3

            if pgrep -f "$PROC" > /dev/null; then
                echo "[$HOSTNAME] $PROC未能优雅关闭，使用SIGKILL..."
                pkill -9 -f "$PROC"
                sleep 2
            fi
        fi
    done

    # 从配置文件中提取目录信息
    if [ -f "$HADOOP_CONF_DIR/hdfs-site.xml" ]; then
        # 提取NameNode数据目录
        NN_DIRS=$(grep -A1 "dfs.namenode.name.dir" "$HADOOP_CONF_DIR/hdfs-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g' | tr ',' ' ')
        NN_DIRS=$(echo "$NN_DIRS" | sed 's|file:||g')

        # 提取DataNode数据目录
        DN_DIRS=$(grep -A1 "dfs.datanode.data.dir" "$HADOOP_CONF_DIR/hdfs-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g' | tr ',' ' ')
        DN_DIRS=$(echo "$DN_DIRS" | sed 's|file:||g')

        # 提取JournalNode数据目录
        JN_DIRS=$(grep -A1 "dfs.journalnode.edits.dir" "$HADOOP_CONF_DIR/hdfs-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g' | tr ',' ' ')
        JN_DIRS=$(echo "$JN_DIRS" | sed 's|file:||g')

        echo "[$HOSTNAME] NameNode数据目录: $NN_DIRS"
        echo "[$HOSTNAME] DataNode数据目录: $DN_DIRS"
        echo "[$HOSTNAME] JournalNode数据目录: $JN_DIRS"
    else
        echo "[$HOSTNAME] 警告: 找不到hdfs-site.xml文件"
    fi

    # 从core-site.xml中获取临时目录
    if [ -f "$HADOOP_CONF_DIR/core-site.xml" ]; then
        TMP_DIR=$(grep -A1 "hadoop.tmp.dir" "$HADOOP_CONF_DIR/core-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g')
        echo "[$HOSTNAME] Hadoop临时目录: $TMP_DIR"
    else
        TMP_DIR="/opt/hadoop/tmp"
        echo "[$HOSTNAME] 警告: 找不到core-site.xml文件, 使用默认临时目录: $TMP_DIR"
    fi

    # 默认目录
    DEFAULT_DIRS=(
        "/opt/hadoop/tmp"
        "/opt/hadoop/hdfs/name"
        "/opt/hadoop/hdfs/data"
        "/opt/hadoop/journalnode"
    )

    # 合并所有需要处理的目录
    ALL_DIRS=("${DEFAULT_DIRS[@]}")

    # 添加从配置文件提取的目录
    for dir_var in "$NN_DIRS" "$DN_DIRS" "$JN_DIRS" "$TMP_DIR"; do
        if [ -n "$dir_var" ]; then
            for dir in $dir_var; do
                if [[ ! " ${ALL_DIRS[@]} " =~ " ${dir} " ]]; then
                    ALL_DIRS+=("$dir")
                fi
            done
        fi
    done

    # 处理所有目录
    for dir in "${ALL_DIRS[@]}"; do
        echo "[$HOSTNAME] 处理目录: $dir"
        if [ -d "$dir" ]; then
            echo "[$HOSTNAME] 删除目录: $dir"
            rm -rf "${dir:?}"
        fi

        echo "[$HOSTNAME] 创建目录: $dir"
        mkdir -p "$dir"
        chmod 755 "$dir"
    done

    echo "[$HOSTNAME] Hadoop目录清理和重建完成"
EOF

    if [ $? -eq 0 ]; then
        echo "节点 $node 上的操作执行成功"
    else
        echo "警告: 节点 $node 上的操作执行失败"
    fi
    echo ""
done

# 步骤3: 启动Journal Node服务
echo "====================================="
echo "步骤3: 启动Journal Node服务"
echo "====================================="

for jn_node in "${JOURNALNODE_NODES[@]}"; do
    echo "启动 $jn_node 上的JournalNode..."
    ssh "$USER@$jn_node" "$HDFS_CMD --daemon start journalnode"
    sleep 2
done

# 等待Journal Node完全启动
echo "等待Journal Node服务完全启动..."
sleep 10

# 步骤4: 格式化ZooKeeper用于HA
echo "====================================="
echo "步骤4: 格式化ZooKeeper用于HA"
echo "====================================="

echo "在主NameNode ($NAMENODE1) 上格式化ZooKeeper..."
ssh "$USER@$NAMENODE1" "$HDFS_CMD zkfc -formatZK -force"

# 步骤5: 格式化主NameNode
echo "====================================="
echo "步骤5: 格式化主NameNode"
echo "====================================="

echo "在主NameNode ($NAMENODE1) 上格式化HDFS..."
ssh "$USER@$NAMENODE1" "$HDFS_CMD namenode -format -force"

# 步骤6: 启动主NameNode
echo "====================================="
echo "步骤6: 启动主NameNode"
echo "====================================="

echo "启动主NameNode ($NAMENODE1)..."
ssh "$USER@$NAMENODE1" "$HDFS_CMD --daemon start namenode"

# 等待主NameNode完全启动
echo "等待主NameNode完全启动..."
sleep 15

# 步骤7: 同步到备NameNode
echo "====================================="
echo "步骤7: 同步到备NameNode"
echo "====================================="

echo "在备NameNode ($NAMENODE2) 上执行bootstrapStandby..."
ssh "$USER@$NAMENODE2" "$HDFS_CMD namenode -bootstrapStandby -force"

# 步骤8: 启动备NameNode
echo "====================================="
echo "步骤8: 启动备NameNode"
echo "====================================="

echo "启动备NameNode ($NAMENODE2)..."
ssh "$USER@$NAMENODE2" "$HDFS_CMD --daemon start namenode"


echo "等待备NameNode完全启动..."
sleep 10

# 步骤9: 启动ZKFC服务
echo "====================================="
echo "步骤9: 启动ZKFC服务"
echo "====================================="

for namenode in "$NAMENODE1" "$NAMENODE2"; do
    echo "启动 $namenode 上的ZKFC..."
    ssh "$USER@$namenode" "$HDFS_CMD --daemon start zkfc"
    sleep 3
done

# 步骤10: 启动DataNode服务
echo "====================================="
echo "步骤10: 启动DataNode服务"
echo "====================================="

for node in "${CLUSTER_NODES[@]}"; do
    echo "启动 $node 上的DataNode..."
    ssh "$USER@$node" "$HDFS_CMD --daemon start datanode"
    sleep 2
done


# 步骤12: 验证集群状态
echo "====================================="
echo "步骤12: 验证集群状态"
echo "====================================="

echo "检查HDFS状态..."
ssh "$USER@$NAMENODE1" "$HDFS_CMD dfsadmin -report"

echo ""
echo "检查NameNode HA状态..."
ssh "$USER@$NAMENODE1" "$HDFS_CMD haadmin -getAllServiceState"

echo ""
echo "=== Hadoop HA集群重置完成 ==="
echo "集群启动完成，请检查以上输出确认所有服务正常运行"
echo ""
echo "常用检查命令："
echo "1. 检查HDFS状态: $HDFS_CMD dfsadmin -report"
echo "2. 检查HA状态: $HDFS_CMD haadmin -getAllServiceState"
echo "3. 检查集群健康: $HDFS_CMD dfsadmin -safemode get"
echo "4. 手动切换NameNode: $HDFS_CMD haadmin -transitionToActive nn1/nn2"