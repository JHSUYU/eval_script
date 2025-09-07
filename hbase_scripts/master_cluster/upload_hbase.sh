#!/bin/bash

# Define variables
SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
OPT_DIR="/opt"
DEST_DIR="/opt/hbase_scripts"

HBASE_TARGET_DIR="/Users/lizhenyu/Desktop/PilotSourceCode/hbase/hbase-assembly/target/hbase-2.5.0-bin.tar.gz"

# Define server list
SERVERS=(
  "ms1205"
  "ms1114"
  "ms1136"
  "ms1116"
  "ms1028"
)

# Copy hbase tar.gz file and scripts directory to all servers using rsync
for SERVER in "${SERVERS[@]}"; do
    # 先通过SSH创建远端目录（如果不存在）
  echo "Cleaning and creating directory on ${SERVER}..."
  ssh "${USER}@${SERVER}.${DOMAIN}" "rm -rf ${DEST_DIR} && mkdir -p ${DEST_DIR}"

  echo "Copying hbase to ${SERVER}..."
  scp -r "${HBASE_TARGET_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"

  echo "上传${SOURCE_DIR}下所有文件到 ${SERVER}..."
  find "${SOURCE_DIR}" -maxdepth 1 -type f -exec scp {} "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}/" \;
done

echo "All transfers completed!"