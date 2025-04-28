# Check if a parameter was provided
if [ $# -eq 0 ]; then
  echo "Error: No ID parameter provided"
  echo "Usage: $0 <server_id>"
  exit 1
fi

# Use the provided parameter as the server ID
SERVER_ID=$1

# Extract and set up Zookeeper
tar -xzf /opt/zookeeper_scripts/zookeeper.tar.gz -C /opt
rm -rf /opt/zookeeper
mv /opt/apache-zookeeper-3.6.2-bin /opt/zookeeper

# Copy configuration file
cp /opt/zookeeper_scripts/zoo.cfg /opt/zookeeper/conf/zoo.cfg

# Clean up and create directories
rm -rf /opt/zookeeper/data
rm -rf /opt/zookeeper/logs
mkdir -p /opt/zookeeper/data
mkdir -p /opt/zookeeper/logs

# Write the server ID to myid file
echo "$SERVER_ID" > /opt/zookeeper/data/myid