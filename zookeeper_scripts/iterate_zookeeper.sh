#!/bin/bash

# Define variables
USER="ZhenyuLi"
HOSTS=(
  "ms1328.utah.cloudlab.us"
  "ms1340.utah.cloudlab.us"
  "ms1325.utah.cloudlab.us"
)
SCRIPT_PATH="/opt/zookeeper_scripts/reconfigure_zookeeper.sh"

# Start with ID 1
SERVER_ID=1

# Iterate through each host and execute script with incrementing ID
for host in "${HOSTS[@]}"; do
  echo "======================================"
  echo "Connecting to $host and executing $SCRIPT_PATH with ID: $SERVER_ID"
  echo "======================================"

  # Connect to the host and execute the script with the current ID
  ssh "$USER@$host" "/bin/zsh $SCRIPT_PATH $SERVER_ID"

  # Check the status of the previous command
  if [ $? -eq 0 ]; then
    echo "Successfully executed script on $host with ID: $SERVER_ID"
  else
    echo "ERROR: Failed to execute script on $host with ID: $SERVER_ID"
  fi

  # Increment the server ID for the next host
  ((SERVER_ID++))
done

echo "All operations completed."