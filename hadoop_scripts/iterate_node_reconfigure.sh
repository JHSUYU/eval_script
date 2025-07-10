#!/bin/bash

USER="ZhenyuLi"
# TODO: Replace the parameter
HOSTS=(
  "ms1018.utah.cloudlab.us"
  "ms1023.utah.cloudlab.us"
  "ms1033.utah.cloudlab.us"
  "ms1022.utah.cloudlab.us"
)
# Define the node names as parameters
# TODO: Replace the parameter
NODE_NAMES=(
  "node0"
  "node1"
  "node2"
  "node3"
)
SCRIPT_PATH="/opt/hadoop_scripts/reconfigure_hadoop.sh"
HADOOP_HOME="/opt/hadoop"
#WORKERS_FILE="$HADOOP_HOME/etc/hadoop/workers"
WORKERS_FILE="$HADOOP_HOME/etc/hadoop/slaves"

# Create the workers file content
WORKERS_CONTENT=$(printf "%s\n" "${NODE_NAMES[@]}")

for host in "${HOSTS[@]}"; do
  echo "======================================"
  echo "Connecting to $host and executing operations"
  echo "======================================"

  # 1. 清理 macOS 系统文件
  echo "清理 $host 上的 macOS 系统文件..."
  ssh "$USER@$host" '
    echo "正在清理 macOS 系统文件..."

    # 先查看要删除的文件（可选）
    macos_files=$(find /opt/hadoop -name "._*" -type f 2>/dev/null | wc -l)
    ds_store_files=$(find /opt/hadoop -name ".DS_Store" -type f 2>/dev/null | wc -l)

    if [ $macos_files -gt 0 ] || [ $ds_store_files -gt 0 ]; then
      echo "发现 $macos_files 个 ._* 文件和 $ds_store_files 个 .DS_Store 文件"

      # 删除 macOS 系统文件
      find /opt/hadoop -name "._*" -type f -delete 2>/dev/null
      find /opt/hadoop -name ".DS_Store" -type f -delete 2>/dev/null

      echo "✓ macOS 系统文件清理完成"
    else
      echo "✓ 未发现 macOS 系统文件"
    fi
  '

  # 检查清理操作的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully cleaned macOS files on $host"
  else
    echo "WARNING: Failed to clean macOS files on $host"
  fi

  # 2. 执行原有的重配置脚本
  echo "执行 $host 上的重配置脚本: $SCRIPT_PATH"
  ssh "$USER@$host" "bash $SCRIPT_PATH"

  # 检查上一个命令的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully executed script on $host"
  else
    echo "ERROR: Failed to execute script on $host"
  fi

  # 3. 更新workers文件
  echo "更新 $host 上的workers文件"
  ssh "$USER@$host" "echo -e '$WORKERS_CONTENT' > $WORKERS_FILE"

  # 检查上一个命令的执行状态
  if [ $? -eq 0 ]; then
    echo "Successfully updated workers file on $host"
  else
    echo "ERROR: Failed to update workers file on $host"
  fi

  # 4. 验证清理结果（可选）
  echo "验证 $host 上的清理结果..."
  ssh "$USER@$host" '
    remaining_files=$(find /opt/hadoop -name "._*" -o -name ".DS_Store" 2>/dev/null | wc -l)
    if [ $remaining_files -eq 0 ]; then
      echo "✓ 确认：所有 macOS 系统文件已清理完成"
    else
      echo "⚠ 警告：仍有 $remaining_files 个系统文件未清理"
    fi
  '

  echo ""  # 添加空行作为分隔
done

echo "======================================"
echo "所有操作完成 - 汇总报告"
echo "======================================"

# 最终验证所有节点的清理状态
echo "最终验证所有节点的清理状态："
for host in "${HOSTS[@]}"; do
  echo -n "$host: "
  remaining=$(ssh "$USER@$host" 'find /opt/hadoop -name "._*" -o -name ".DS_Store" 2>/dev/null | wc -l')
  if [ "$remaining" -eq 0 ]; then
    echo "✓ 清理完成"
  else
    echo "⚠ 仍有 $remaining 个文件"
  fi
done

echo "All operations completed."