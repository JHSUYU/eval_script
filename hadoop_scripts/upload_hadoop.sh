#!/bin/bash

# 定义变量
SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# TODO: Change the Parameter
SERVERS=(
  "ms1145"
  "ms1125"
  "ms1141"
)

# 上传整个SOURCE_DIR文件夹到所有服务器
for SERVER in "${SERVERS[@]}"; do
  echo "上传整个SOURCE_DIR文件夹到 ${SERVER}..."
  scp -r "${SOURCE_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"
done

echo "所有文件上传完成！"