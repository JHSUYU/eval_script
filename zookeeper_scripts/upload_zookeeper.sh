#!/bin/bash

SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# Define server list
SERVERS=(
  "ms0805"
  "ms0832"
  "ms0828"
  "ms0822"
  "ms0820"
)

ZOOKEEPER_TARGET_DIR="/Users/lizhenyu/Desktop/eval_script/HBASE-25898/zookeeper.tar.gz"

# Copy zookeeper_scripts directory to all servers
for SERVER in "${SERVERS[@]}"; do
  echo "Copying zookeeper_scripts directory to ${SERVER}..."
  scp -r "${SOURCE_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"


  echo "Copying ZooKeeper tar.gz to ${SERVER}..."
  scp "${ZOOKEEPER_TARGET_DIR}" "${USER}@${SERVER}.${DOMAIN}:/opt/zookeeper_scripts/"
done

echo "All transfers completed!"