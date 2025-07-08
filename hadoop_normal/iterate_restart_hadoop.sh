#!/bin/bash

# Hadoop相关目录
HADOOP_HOME="/opt/hadoop"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
HDFS_CMD="$HADOOP_HOME/bin/hdfs"
HADOOP_CMD="$HADOOP_HOME/bin/hadoop"

# 集群节点配置
CLUSTER_NODES=("ms1328.utah.cloudlab.us" "ms1340.utah.cloudlab.us" "ms1325.utah.cloudlab.us")
USER="ZhenyuLi"  # 替换为你的用户名
NAMENODE="${CLUSTER_NODES[0]}"

echo "=== Hadoop集群完全重置脚本 ==="
echo "Hadoop主目录: $HADOOP_HOME"
echo "Hadoop配置目录: $HADOOP_CONF_DIR"
echo "集群节点: ${CLUSTER_NODES[*]}"
echo "NameNode: $NAMENODE"

## 检查是否可以访问HDFS命令
#if [ ! -f "$HDFS_CMD" ]; then
#    echo "无法找到HDFS命令: $HDFS_CMD"
#    echo "请检查HADOOP_HOME环境变量是否正确"
#    exit 1
#fi

# 步骤1: 在NameNode节点上停止Hadoop服务
echo "正在NameNode节点上停止Hadoop服务..."
ssh "$USER@$NAMENODE" "bash -s" << EOF
        if [ -f "$HADOOP_HOME/sbin/stop-dfs.sh" ]; then
            "$HADOOP_HOME/sbin/stop-dfs.sh"
        else
            echo "错误: 找不到stop-dfs.sh脚本"
            exit 1
        fi

        if [ -f "$HADOOP_HOME/sbin/stop-yarn.sh" ]; then
            "$HADOOP_HOME/sbin/stop-yarn.sh"
        fi
EOF

# 等待服务完全停止
echo "等待Hadoop服务完全停止..."
sleep 10

# 在所有节点上执行清理操作
for node in "${CLUSTER_NODES[@]}"; do
    echo "====================================="
    echo "正在处理节点: $node"
    echo "====================================="

    # SSH到节点并执行清理操作
    ssh "$USER@$node" "bash -s" << 'EOF'
    # 获取主机名，用于日志
    HOSTNAME=$(hostname)
    echo "[$HOSTNAME] 开始清理Hadoop数据..."

    # Hadoop相关目录
    HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}
    HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-"$HADOOP_HOME/etc/hadoop"}

    # 确保所有相关进程已停止
    for PROC in "namenode" "datanode" "secondarynamenode" "resourcemanager" "nodemanager"; do
        if pgrep -f "$PROC" > /dev/null; then
            echo "[$HOSTNAME] 正在停止残留的$PROC进程..."
            pkill -f "$PROC"
            sleep 3

            # 如果还在运行，使用SIGKILL
            if pgrep -f "$PROC" > /dev/null; then
                echo "[$HOSTNAME] $PROC未能优雅关闭，使用SIGKILL..."
                pkill -9 -f "$PROC"
                sleep 2
            fi
        fi
    done

    # 从hdfs-site.xml中获取数据目录
    if [ -f "$HADOOP_CONF_DIR/hdfs-site.xml" ]; then
        # 提取NameNode数据目录
        NN_DIRS=$(grep -A1 "dfs.namenode.name.dir" "$HADOOP_CONF_DIR/hdfs-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g' | tr ',' ' ')
        NN_DIRS=$(echo "$NN_DIRS" | sed 's|file:||g')

        # 提取DataNode数据目录
        DN_DIRS=$(grep -A1 "dfs.datanode.data.dir" "$HADOOP_CONF_DIR/hdfs-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g' | tr ',' ' ')
        DN_DIRS=$(echo "$DN_DIRS" | sed 's|file:||g')

        echo "[$HOSTNAME] NameNode数据目录: $NN_DIRS"
        echo "[$HOSTNAME] DataNode数据目录: $DN_DIRS"
    else
        echo "[$HOSTNAME] 警告: 找不到hdfs-site.xml文件"
    fi

    # 从core-site.xml中获取临时目录
    if [ -f "$HADOOP_CONF_DIR/core-site.xml" ]; then
        # 提取临时目录
        TMP_DIR=$(grep -A1 "hadoop.tmp.dir" "$HADOOP_CONF_DIR/core-site.xml" | grep -o "<value>.*</value>" | sed 's/<value>//g' | sed 's/<\/value>//g')
        echo "[$HOSTNAME] Hadoop临时目录: $TMP_DIR"
    else
        # 默认临时目录
        TMP_DIR="/opt/hadoop/tmp"
        echo "[$HOSTNAME] 警告: 找不到core-site.xml文件, 使用默认临时目录: $TMP_DIR"
    fi

    # 删除并重建所有目录
    echo "[$HOSTNAME] 清理并重建Hadoop目录..."

    # 默认目录 - 无论如何都创建这些目录
    DEFAULT_DIRS=(
        "/opt/hadoop/tmp"
        "/opt/hadoop/hdfs/name"
        "/opt/hadoop/hdfs/data"
    )

    # 合并所有需要处理的目录
    ALL_DIRS=("${DEFAULT_DIRS[@]}")

    # 添加从配置文件提取的目录
    if [ -n "$NN_DIRS" ]; then
        for dir in $NN_DIRS; do
            if [[ ! " ${ALL_DIRS[@]} " =~ " ${dir} " ]]; then
                ALL_DIRS+=("$dir")
            fi
        done
    fi

    if [ -n "$DN_DIRS" ]; then
        for dir in $DN_DIRS; do
            if [[ ! " ${ALL_DIRS[@]} " =~ " ${dir} " ]]; then
                ALL_DIRS+=("$dir")
            fi
        done
    fi

    if [ -n "$TMP_DIR" ] && [[ ! " ${ALL_DIRS[@]} " =~ " ${TMP_DIR} " ]]; then
        ALL_DIRS+=("$TMP_DIR")
    fi

    # 处理所有目录
    for dir in "${ALL_DIRS[@]}"; do
        echo "[$HOSTNAME] 处理目录: $dir"
        # 删除目录（如果存在）
        if [ -d "$dir" ]; then
            echo "[$HOSTNAME] 删除目录: $dir"
            rm -rf "${dir:?}"
        fi

        # 重新创建目录
        echo "[$HOSTNAME] 创建目录: $dir"
        mkdir -p "$dir"

        # 设置适当的权限
        chmod 755 "$dir"
    done

    echo "[$HOSTNAME] Hadoop目录清理和重建完成"
EOF

    # 检查是否执行成功
    if [ $? -eq 0 ]; then
        echo "节点 $node 上的操作执行成功"
    else
        echo "警告: 节点 $node 上的操作执行失败"
    fi

    echo ""  # 添加空行作为分隔
done

# 步骤4: 在NameNode上格式化HDFS
echo "正在NameNode上格式化HDFS..."
echo "使用节点: $NAMENODE"

# 使用变量而不是硬编码SSH命令
ssh "$USER@$NAMENODE" "$HDFS_CMD namenode -format -force"

# 完成消息 - 也通过SSH在NameNode上显示启动命令
echo "=== Hadoop集群重置完成 ==="
echo "现在将在NameNode ($NAMENODE) 上启动Hadoop集群"

ssh "$USER@$NAMENODE" "$HADOOP_HOME/sbin/start-all.sh"