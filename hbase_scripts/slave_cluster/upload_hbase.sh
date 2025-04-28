#!/bin/bash

# Define variables
SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
OPT_DIR="/opt"
DEST_DIR="/opt/hbase_scripts"

HBASE_TARGET_DIR="/Users/lizhenyu/Desktop/AutoPilotEval/hbase-25898-2.5-pilot/hbase-assembly/target/hbase-2.5.12-SNAPSHOT-bin.tar.gz"

# Define server list
SERVERS=(
  "ms1110"
  "ms1143"
  "ms1014"
)

# Copy hbase tar.gz file and scripts directory to all servers using rsync
for SERVER in "${SERVERS[@]}"; do
  echo "Copying hbase to ${SERVER}..."
  rsync -avz HBASE_TARGET_DIR "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"

  echo "Copying scripts directory to ${SERVER}..."
  rsync -avz "${SOURCE_DIR}/hbase_scripts" "${USER}@${SERVER}.${DOMAIN}:${OPT_DIR}"
done

echo "All transfers completed!"