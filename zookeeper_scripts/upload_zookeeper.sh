#!/bin/bash

# Define variables
SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# Define server list
SERVERS=(
  "ms1145"
  "ms1125"
  "ms1141"
  "ms1110"
  "ms1143"
  "ms1014"
)

# Copy zookeeper_scripts directory to all servers
for SERVER in "${SERVERS[@]}"; do
  echo "Copying zookeeper_scripts directory to ${SERVER}..."
  scp -r "${SOURCE_DIR}" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}"
done

echo "All transfers completed!"