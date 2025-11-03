#!/bin/bash

# Define variables
USER="ZhenyuLi"
HOSTS=(
  "clnode311.clemson.cloudlab.us"
  "clnode314.clemson.cloudlab.us"
)

# Internal IP addresses (corresponding to HOSTS array order)
INTERNAL_IPS=(
  "10.10.1.1"
  "10.10.1.2"
)

# Solr configuration
SOLR_BIN="/opt/Solr/solr/bin/solr"
SOLR_DATA="/opt/SolrData"
SOLR_PORT="8983"
SOLR_MEMORY="8g"
SOLR_CONFIG_DIR="/opt/Solr/conf"
CONFIG_NAME="myconfig"

# Build ZooKeeper ensemble string
ZK_ENSEMBLE=""
for ip in "${INTERNAL_IPS[@]}"; do
  if [ -z "$ZK_ENSEMBLE" ]; then
    ZK_ENSEMBLE="${ip}:2181"
  else
    ZK_ENSEMBLE="${ZK_ENSEMBLE},${ip}:2181"
  fi
done
# If you have a third node, add it manually or extend the array
ZK_ENSEMBLE="${ZK_ENSEMBLE},10.10.1.3:2181"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}======================================"
echo "Starting Solr Cluster"
echo "======================================"
echo -e "${NC}"
echo "ZooKeeper Ensemble: $ZK_ENSEMBLE"
echo ""

# Function to start Solr on each node
start_solr_node() {
  local host=$1
  local internal_ip=$2
  local node_index=$3

  echo -e "${GREEN}======================================${NC}"
  echo -e "${GREEN}Starting Solr on $host (IP: $internal_ip)${NC}"
  echo -e "${GREEN}======================================${NC}"

  # SSH and start Solr
  ssh "$USER@$host" << EOF
    echo "Starting Solr node..."

    # Check if Solr is already running
    if $SOLR_BIN status 2>/dev/null | grep -q "running"; then
      echo "⚠ Solr is already running. Stopping it first..."
      $SOLR_BIN stop -all
      sleep 5
    fi

    # Start Solr in cloud mode
    echo "Executing: $SOLR_BIN start -c -z $ZK_ENSEMBLE -p $SOLR_PORT -h $internal_ip -s $SOLR_DATA -m $SOLR_MEMORY"

    $SOLR_BIN start -c \
      -z $ZK_ENSEMBLE \
      -p $SOLR_PORT \
      -h $internal_ip \
      -s $SOLR_DATA \
      -m $SOLR_MEMORY

    if [ \$? -eq 0 ]; then
      echo "✓ Solr started successfully"

      # Wait for Solr to fully start
      sleep 10

      # Verify Solr is running
      $SOLR_BIN status
    else
      echo "✗ Failed to start Solr"
      exit 1
    fi
EOF

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully started Solr on $host${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed to start Solr on $host${NC}"
    return 1
  fi
}

# Function to upload configuration (only on first node)
upload_config() {
  local host=$1

  echo -e "${YELLOW}======================================${NC}"
  echo -e "${YELLOW}Uploading configuration from $host${NC}"
  echo -e "${YELLOW}======================================${NC}"

  ssh "$USER@$host" << EOF
    echo "Uploading Solr configuration to ZooKeeper..."

    # Check if config already exists
    echo "Checking existing configurations..."
    $SOLR_BIN zk ls -r /configs -z $ZK_ENSEMBLE 2>/dev/null || true

    # Upload configuration
    echo "Executing: $SOLR_BIN zk upconfig -n $CONFIG_NAME -d $SOLR_CONFIG_DIR -z $ZK_ENSEMBLE"

    $SOLR_BIN zk upconfig \
      -n $CONFIG_NAME \
      -d $SOLR_CONFIG_DIR \
      -z $ZK_ENSEMBLE

    if [ \$? -eq 0 ]; then
      echo "✓ Configuration uploaded successfully"

      # Verify upload
      echo "Verifying configuration in ZooKeeper:"
      $SOLR_BIN zk ls -r /configs/$CONFIG_NAME -z $ZK_ENSEMBLE 2>/dev/null | head -20
    else
      echo "✗ Failed to upload configuration"
      exit 1
    fi
EOF

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Configuration uploaded successfully${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed to upload configuration${NC}"
    return 1
  fi
}

# Main execution
echo -e "${GREEN}Phase 1: Starting all Solr nodes in parallel${NC}"
echo ""

# Array to store PIDs
declare -a PIDS=()

# Start all Solr nodes in parallel
for i in "${!HOSTS[@]}"; do
  {
    start_solr_node "${HOSTS[$i]}" "${INTERNAL_IPS[$i]}" "$i"
  } &
  PIDS+=($!)
  echo -e "${YELLOW}Started background process for ${HOSTS[$i]} (PID: ${PIDS[-1]})${NC}"
done

# Wait for all nodes to start
echo -e "${YELLOW}Waiting for all nodes to start...${NC}"
FAILED_NODES=()
SUCCESS_NODES=()

for i in "${!HOSTS[@]}"; do
  wait "${PIDS[$i]}"
  if [ $? -eq 0 ]; then
    SUCCESS_NODES+=("${HOSTS[$i]}")
  else
    FAILED_NODES+=("${HOSTS[$i]}")
  fi
done

# Check if any nodes failed
if [ ${#FAILED_NODES[@]} -gt 0 ]; then
  echo -e "${RED}Failed to start the following nodes:${NC}"
  for node in "${FAILED_NODES[@]}"; do
    echo -e "${RED}  - $node${NC}"
  done
  echo -e "${RED}Aborting. Please check the failed nodes.${NC}"
  exit 1
fi

echo -e "${GREEN}All nodes started successfully!${NC}"
echo ""

# Wait for cluster to stabilize
echo "Waiting for cluster to stabilize..."
sleep 15

# Upload configuration from first node
echo -e "${GREEN}Phase 2: Uploading configuration${NC}"
echo ""
upload_config "${HOSTS[0]}"

if [ $? -ne 0 ]; then
  echo -e "${RED}Failed to upload configuration. Please check and retry.${NC}"
  exit 1
fi

# Final status check - also in parallel
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Final Status Check${NC}"
echo -e "${GREEN}======================================${NC}"

# Parallel status check
for host in "${HOSTS[@]}"; do
  {
    echo -e "${YELLOW}Status of $host:${NC}"
    ssh "$USER@$host" "$SOLR_BIN status" 2>/dev/null
    echo ""
  } &
done

# Wait for all status checks to complete
wait

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Solr cluster startup complete!${NC}"
echo -e "${GREEN}======================================${NC}"