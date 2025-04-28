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
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin' >> ~/.zshrc
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.zshrc

source ~/.zshrc