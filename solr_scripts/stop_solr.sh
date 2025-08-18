#!/bin/bash

# Define variables
USER="ZhenyuLi"
HOSTS=(
  "ms1132.utah.cloudlab.us"
  "ms1101.utah.cloudlab.us"
)
SOLR_BIN="/opt/Solr/solr/bin/solr"
SOLR_DATA_DIR="/opt/SolrData"

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

    # Alternative Method 2: If you want to be more aggressive
    # cd /opt/SolrData
    # ls | grep -v '\.xml$' | xargs rm -rf 2>/dev/null

    echo "Cleanup completed"

    # Verify remaining files
    echo "Remaining files in /opt/SolrData:"
    ls -la /opt/SolrData/
EOF

  # Check the status of the SSH command
  if [ $? -eq 0 ]; then
    echo "✓ Successfully completed operations on $host"
  else
    echo "✗ ERROR: Failed to complete operations on $host"
  fi

  echo ""
}

# Main execution

# Iterate through each host
for host in "${HOSTS[@]}"; do
  stop_and_clean "$host"
done

echo "======================================"
echo "All operations completed."
echo "======================================"

# Optional: Check status on all nodes
echo ""
echo "Checking Solr status on all nodes:"
for host in "${HOSTS[@]}"; do
  echo -n "$host: "
  ssh "$USER@$host" "$SOLR_BIN status" 2>/dev/null | grep "No Solr nodes" > /dev/null
  if [ $? -eq 0 ]; then
    echo "Stopped ✓"
  else
    echo "Still running or error"
  fi
done