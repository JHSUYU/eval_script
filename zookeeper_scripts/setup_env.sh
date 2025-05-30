sudo apt-get update
sudo apt install git maven ant openjdk-8-jdk
sudo update-alternatives --set java $(sudo update-alternatives --list java | grep "java-8")

sudo chmod -R a+rw /opt

rm -rf /opt/hadoop/tmp
rm -rf /opt/hadoop/hdfs/name
rm -rf /opt/hadoop/hdfs/data

mkdir -p /opt/hadoop/tmp
mkdir -p /opt/hadoop/hdfs/name
mkdir -p /opt/hadoop/hdfs/data

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