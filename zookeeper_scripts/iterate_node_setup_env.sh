#!/bin/bash

# 定义变量
USER="ZhenyuLi"
HOSTS=(
  "ms1205.utah.cloudlab.us"
  "ms1114.utah.cloudlab.us"
  "ms1136.utah.cloudlab.us"
  "ms1116.utah.cloudlab.us"
  "ms1028.utah.cloudlab.us"
)
SCRIPT_PATH="/opt/zookeeper_scripts/setup_env.sh"

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
  echo ""  # 添加空行作为分隔
done

echo "All operations completed."