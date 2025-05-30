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
  "ms1328"
  "ms1340"
  "ms1325"
)

# Copy hbase tar.gz file and scripts directory to all servers using rsync
for SERVER in "${SERVERS[@]}"; do
  echo "Copying hbase to ${SERVER}..."
  rsync -avz "${HBASE_TARGET_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"

  echo "上传${SOURCE_DIR}下所有文件到 ${SERVER}..."
  find "${SOURCE_DIR}" -maxdepth 1 -type f -exec rsync -avz {} "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}/" \;
done

echo "All transfers completed!"