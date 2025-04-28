#!/bin/bash

# Define path to HBase installation
HBASE_HOME="/opt/hbase"

# Check if HBase directory exists
if [ ! -d "$HBASE_HOME" ]; then
  echo "Error: HBase installation directory not found at $HBASE_HOME"
  exit 1
fi

# Check if hbase-daemon.sh exists
if [ ! -f "$HBASE_HOME/bin/hbase-daemon.sh" ]; then
  echo "Error: hbase-daemon.sh not found at $HBASE_HOME/bin"
  exit 1
fi

# Stop all HRegionServers
echo "Stopping all HRegionServers..."
"$HBASE_HOME/bin/hbase-daemon.sh" stop regionserver

# Give HRegionServers time to shut down properly
echo "Waiting for HRegionServers to stop..."
sleep 5

# Stop all HMasters
echo "Stopping all HMasters..."
"$HBASE_HOME/bin/hbase-daemon.sh" stop master

echo "All HBase services have been stopped."

# Optionally verify if processes are still running
if pgrep -f "org.apache.hadoop.hbase.master.HMaster" > /dev/null; then
  echo "Warning: Some HMaster processes are still running."
  ps -ef | grep "org.apache.hadoop.hbase.master.HMaster" | grep -v grep
fi

if pgrep -f "org.apache.hadoop.hbase.regionserver.HRegionServer" > /dev/null; then
  echo "Warning: Some HRegionServer processes are still running."
  ps -ef | grep "org.apache.hadoop.hbase.regionserver.HRegionServer" | grep -v grep
fi