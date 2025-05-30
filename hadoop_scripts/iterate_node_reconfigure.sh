#!/bin/bash

USER="ZhenyuLi"
# TODO: Replace the parameter
HOSTS=(
  "ms1328.utah.cloudlab.us"
  "ms1340.utah.cloudlab.us"
  "ms1325.utah.cloudlab.us"
)
# Define the node names as parameters
# TODO: Replace the parameter
NODE_NAMES=(
  "node0"
  "node1"
  "node2"
)
SCRIPT_PATH="/opt/hadoop_scripts/reconfigure_hadoop.sh"
HADOOP_HOME="/opt/hadoop"
WORKERS_FILE="$HADOOP_HOME/etc/hadoop/slaves"

# Create the workers file content
WORKERS_CONTENT=$(printf "%s\n" "${NODE_NAMES[@]}")

for host in "${HOSTS[@]}"; do
  echo "======================================"
  echo "Connecting to $host and executing $SCRIPT_PATH"
  echo "======================================"

  ssh "$USER@$host" "bash $SCRIPT_PATH"

  # 检查上一个命令的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully executed script on $host"
  else
    echo "ERROR: Failed to execute script on $host"
  fi

  # 确保workers文件在每个节点上都是一致的
  echo "更新 $host 上的workers文件"
  # Using the parameterized node names
  ssh "$USER@$host" "echo -e '$WORKERS_CONTENT' > $HADOOP_HOME/etc/hadoop/slaves"

  # 检查上一个命令的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully updated workers file on $host"
  else
    echo "ERROR: Failed to update workers file on $host"
  fi

  echo ""  # 添加空行作为分隔
done

echo "All operations completed."