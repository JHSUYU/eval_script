#!/bin/bash

# Define variables
USER="ZhenyuLi"
HOSTS=(
  "clnode311.clemson.cloudlab.us"
  "clnode314.clemson.cloudlab.us"
)
SOLR_BIN="/opt/Solr/solr/bin/solr"
SOLR_DATA_DIR="/opt/SolrData"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to stop Solr and clean data on each host
stop_and_clean() {
  local host=$1
  echo "======================================"
  echo "Processing $host"
  echo "======================================"

  # SSH to host and execute commands
  ssh "$USER@$host" << 'EOF'
    echo "Stopping Solr..."
    /opt/Solr/solr/bin/solr stop -all

    # Check if Solr stopped successfully
    if [ $? -eq 0 ]; then
      echo "Solr stopped successfully"
    else
      echo "Warning: Solr stop command returned non-zero status"
    fi

    # Wait a moment for Solr to fully stop
    sleep 3

    echo "Cleaning SolrData directory (keeping .xml files)..."

    # Method 1: Delete everything except .xml files
    find /opt/SolrData -type f ! -name "*.xml" -delete 2>/dev/null
    find /opt/SolrData -type d -empty -delete 2>/dev/null

    echo "Cleanup completed"

    rm -rf /opt/ShadowDirectory
    rm -rf /opt/ShadowAppendLog

    # Verify remaining files
    echo "Remaining files in /opt/SolrData:"
    ls -la /opt/SolrData/
EOF

  # Check the status of the SSH command
  if [ $? -eq 0 ]; then
    echo "✓ Successfully completed operations on $host"
    return 0
  else
    echo "✗ ERROR: Failed to complete operations on $host"
    return 1
  fi
}

# Main execution
echo -e "${GREEN}Starting parallel Solr shutdown and cleanup on ${#HOSTS[@]} hosts...${NC}"
echo "======================================"

# Array to store background process PIDs
declare -a PIDS=()

# Start all processes in parallel
for host in "${HOSTS[@]}"; do
  {
    stop_and_clean "$host"
  } &
  PIDS+=($!)
  echo -e "${YELLOW}Started process for $host (PID: ${PIDS[-1]})${NC}"
done

# Wait for all background processes to complete
echo -e "\n${YELLOW}Waiting for all processes to complete...${NC}"
FAILED_HOSTS=()
SUCCESS_HOSTS=()

for i in "${!HOSTS[@]}"; do
  wait "${PIDS[$i]}"
  if [ $? -eq 0 ]; then
    SUCCESS_HOSTS+=("${HOSTS[$i]}")
  else
    FAILED_HOSTS+=("${HOSTS[$i]}")
  fi
done

# Summary
echo ""
echo "======================================"
echo "All operations completed."
echo "======================================"
echo -e "${GREEN}Successfully processed: ${#SUCCESS_HOSTS[@]} hosts${NC}"
for host in "${SUCCESS_HOSTS[@]}"; do
  echo -e "  ${GREEN}✓ $host${NC}"
done

if [ ${#FAILED_HOSTS[@]} -gt 0 ]; then
  echo -e "${RED}Failed: ${#FAILED_HOSTS[@]} hosts${NC}"
  for host in "${FAILED_HOSTS[@]}"; do
    echo -e "  ${RED}✗ $host${NC}"
  done
fi

# Check status on all nodes
echo ""
echo "Checking Solr status on all nodes:"
for host in "${HOSTS[@]}"; do
  echo -n "$host: "
  ssh "$USER@$host" "$SOLR_BIN status" 2>/dev/null | grep "No Solr nodes" > /dev/null
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Stopped ✓${NC}"
  else
    echo -e "${RED}Still running or error${NC}"
  fi
done