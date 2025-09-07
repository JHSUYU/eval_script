#!/bin/bash

# Define nodes and HBase installation path
NODES=("node0" "node1" "node2" "node3" "node4")
HBASE_HOME="/opt/hbase"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Stopping HBase cluster on all nodes...${NC}"
echo "================================================"

# Function to stop HBase on a single node
stop_hbase_on_node() {
    local node=$1
    echo -e "\n${GREEN}Processing $node...${NC}"

    ssh $node "bash -s" << 'ENDSSH'
    HBASE_HOME="/opt/hbase"

    # Stop services gracefully
    if [ -f "$HBASE_HOME/bin/hbase-daemon.sh" ]; then
        $HBASE_HOME/bin/hbase-daemon.sh stop regionserver 2>/dev/null
        sleep 2
        $HBASE_HOME/bin/hbase-daemon.sh stop master 2>/dev/null
        sleep 2
    fi

    # Force kill remaining processes
    # Kill HRegionServer
    pids=$(pgrep -f "org.apache.hadoop.hbase.regionserver.HRegionServer")
    if [ -n "$pids" ]; then
        echo "  Force killing HRegionServer processes: $pids"
        kill -9 $pids 2>/dev/null
    fi

    # Kill HMaster
    pids=$(pgrep -f "org.apache.hadoop.hbase.master.HMaster")
    if [ -n "$pids" ]; then
        echo "  Force killing HMaster processes: $pids"
        kill -9 $pids 2>/dev/null
    fi

    # Kill HQuorumPeer
    pids=$(pgrep -f "org.apache.hadoop.hbase.zookeeper.HQuorumPeer")
    if [ -n "$pids" ]; then
        echo "  Force killing HQuorumPeer processes: $pids"
        kill -9 $pids 2>/dev/null
    fi

    # Clean PID files
    rm -f $HBASE_HOME/logs/*.pid 2>/dev/null

    # Verify
    if pgrep -f "org.apache.hadoop.hbase" > /dev/null; then
        echo "  ⚠ Warning: Some HBase processes still running"
        ps aux | grep "org.apache.hadoop.hbase" | grep -v grep
    else
        echo "  ✓ All HBase processes stopped"
    fi
ENDSSH
}

# Stop HBase on all nodes
for node in "${NODES[@]}"; do
    stop_hbase_on_node $node
done

echo -e "\n================================================"
echo -e "${GREEN}HBase cluster shutdown complete on all nodes!${NC}"

# Final cluster-wide verification
echo -e "\n${YELLOW}Cluster-wide verification:${NC}"
for node in "${NODES[@]}"; do
    echo -n "  $node: "
    ssh $node "pgrep -f 'org.apache.hadoop.hbase' > /dev/null && echo '✗ HBase processes still running' || echo '✓ Clean'" 2>/dev/null
done