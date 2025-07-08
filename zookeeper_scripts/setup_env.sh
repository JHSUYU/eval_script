echo 'export HADOOP_HOME="/opt/hadoop"' >> ~/.zshrc
echo 'export HBASE_HOME="/opt/hbase"' >> ~/.zshrc
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> ~/.zshrc
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.zshrc
echo "export CASSANDRA_HOME=/opt/cassandra" >> ~/.zshrc
echo 'export PATH=$PATH:$CASSANDRA_HOME/bin' >> ~/.zshrc

echo "export CASSANDRA_HOME=/opt/cassandra" >> ~/.bashrc
echo 'export PATH=$PATH:$CASSANDRA_HOME/bin' >> ~/.bashrc

source ~/.bashrc
source ~/.zshrc