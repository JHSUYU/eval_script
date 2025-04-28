#!/bin/bash

SOURCE_DIR="$(pwd)"
USER="ZhenyuLi"
DOMAIN="utah.cloudlab.us"
DEST_DIR="/opt"

# Define server list
SERVERS=(
  "ms1126"
  "ms1138"
  "ms1114"
  "ms1222"
)

# Copy script files to servers using rsync
echo "Copying stop scripts to servers..."

# Iterate through each server in the SERVERS array
for SERVER in "${SERVERS[@]}"; do
  echo "Copying files to ${SERVER}..."
  rsync -avz "${SOURCE_DIR}/setup_env.sh" "${USER}@${SERVER}.${DOMAIN}:${DEST_DIR}/"
done


echo "All transfers completed!"