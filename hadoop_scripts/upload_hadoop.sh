#!/bin/bash

# 定义变量
SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# TODO: Change the Parameter
SERVERS=(
  "ms1108"
  "ms1145"
  "ms1125"
)

HBASE_TARGET_DIR="/Users/lizhenyu/Desktop/AutoPilotEval/hadoop-2.6.0-10320/hadoop-dist/target/hadoop-2.6.0.tar.gz"

# 上传整个SOURCE_DIR文件夹到所有服务器
for SERVER in "${SERVERS[@]}"; do
  echo "上传整个SOURCE_DIR文件夹到 ${SERVER}..."
  scp -r "${SOURCE_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"

  echo "Copying Hadoop tar.gz to ${SERVER}..."
  scp "${HBASE_TARGET_DIR}" "${USER}@${SERVER}.${DOMAIN}:/opt/hadoop_scripts/"
done

echo "所有文件上传完成！"