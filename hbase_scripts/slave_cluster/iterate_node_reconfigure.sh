#!/bin/bash

# 定义变量
USER="ZhenyuLi"
HOSTS=(
  "ms1110.utah.cloudlab.us"
  "ms1143.utah.cloudlab.us"
  "ms1141.utah.cloudlab.us"
)
SCRIPT_PATH="/opt/hbase_scripts/master_cluster/reconfigure_hbase.sh"
REGIONSERVERS_PATH="/opt/hbase/conf/regionservers"
HBASE_ENV_PATH="/opt/hbase/conf/hbase-env.sh"

# 定义RegionServers列表（可以自由修改）
REGION_SERVERS=(
  "node1"
  "node2"
)

# 定义要添加到hbase-env.sh的配置
HBASE_ENV_CONFIG="
# 设置Java环境
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64

# 如果使用外部ZooKeeper，设置为false
export HBASE_MANAGES_ZK=false

# 配置HBase日志目录
export HBASE_LOG_DIR=/opt/hbase/logs

# 设置Hadoop目录
export HADOOP_HOME=/opt/hadoop
"

# 依次SSH到每个节点并执行脚本
for host in "${HOSTS[@]}"; do
  echo "======================================"
  echo "Connecting to $host and executing $SCRIPT_PATH"
  echo "======================================"

  # 连接到主机并执行脚本
  ssh "$USER@$host" "bash $SCRIPT_PATH"

  # 检查上一个命令的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully executed script on $host"
  else
    echo "ERROR: Failed to execute script on $host"
  fi

  # 更新regionservers文件内容
  echo "Updating regionservers configuration on $host"

  # 创建临时文件
  TEMP_RS_FILE=$(mktemp)
  printf "%s\n" "${REGION_SERVERS[@]}" > "$TEMP_RS_FILE"

  # 复制到远程服务器
  scp "$TEMP_RS_FILE" "$USER@$host:$REGIONSERVERS_PATH"
  rm "$TEMP_RS_FILE"

  # 检查配置文件更新状态
  if [ $? -eq 0 ]; then
    echo "Successfully updated regionservers configuration on $host"
  else
    echo "ERROR: Failed to update regionservers configuration on $host"
  fi

  # 更新hbase-env.sh文件
  echo "Updating hbase-env.sh on $host"
  ssh "$USER@$host" "echo '$HBASE_ENV_CONFIG' >> $HBASE_ENV_PATH"

  # 检查hbase-env.sh更新状态
  if [ $? -eq 0 ]; then
    echo "Successfully updated hbase-env.sh on $host"
  else
    echo "ERROR: Failed to update hbase-env.sh on $host"
  fi

  echo ""  # 添加空行作为分隔
done

echo "All operations completed."