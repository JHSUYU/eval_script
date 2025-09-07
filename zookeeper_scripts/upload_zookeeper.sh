#!/bin/bash

SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# Define server list
SERVERS=(
  "ms1205"
  "ms1114"
  "ms1136"
)

ZOOKEEPER_TARGET_DIR="/Users/lizhenyu/Desktop/eval_script/HBASE-25898/zookeeper.tar.gz"

# Start all transfers in background
for SERVER in "${SERVERS[@]}"; do
  (
    echo "Starting transfer to ${SERVER}..."
    scp -r "${SOURCE_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"
    echo "Copying ZooKeeper tar.gz to ${SERVER}..."
    scp "${ZOOKEEPER_TARGET_DIR}" "${USER}@${SERVER}.${DOMAIN}:/opt/zookeeper_scripts/"
    echo "Completed transfer to ${SERVER}"
  ) &
done

# Wait for all background jobs to complete
wait

echo "All transfers completed!"