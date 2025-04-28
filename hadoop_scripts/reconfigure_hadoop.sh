#!/bin/bash

# Define installation directory variables
INSTALL_DIR="/opt/hadoop_scripts"
OPT="/opt"

# Define node parameters (these can be set when running the script)
NODE_X="node0"
NODE_Y="node1"
NODE_Z="node2"

# Unpack Hadoop to installation directory
tar -xzf ${INSTALL_DIR}/hadoop-2.9.0.tar.gz -C ${INSTALL_DIR}
rm -rf ${OPT}/hadoop
mv ${INSTALL_DIR}/hadoop-2.9.0 ${OPT}/hadoop

# Update core-site.xml with node parameters
cat > ${OPT}/hadoop/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${NODE_X}:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF

# Update hdfs-site.xml with node parameters
cat > ${OPT}/hadoop/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/opt/hadoop/hdfs/name</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/hdfs/data</value>
    </property>
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>dfs.permissions.enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>${NODE_X}:9870</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-address</name>
        <value>${NODE_X}:9000</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>${NODE_Y}:9870</value>
    </property>
    <property>
        <name>dfs.namenode.secondary.rpc-address</name>
        <value>${NODE_Y}:9000</value>
    </property>
</configuration>
EOF

# Update mapred-site.xml with node parameters
cat > ${OPT}/hadoop/etc/hadoop/mapred-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=\$HADOOP_HOME</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.address</name>
        <value>${NODE_X}:10020</value>
    </property>
    <property>
        <name>mapreduce.jobhistory.webapp.address</name>
        <value>${NODE_X}:19888</value>
    </property>
</configuration>
EOF

# Update yarn-site.xml with node parameters
cat > ${OPT}/hadoop/etc/hadoop/yarn-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.auxservices.mapreduce.shuffle.class</name>
        <value>org.apache.hadoop.mapred.ShuffleHandler</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-pmem-ratio</name>
        <value>4</value>
    </property>
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.log-aggregation-enable</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.log-aggregation.retain-seconds</name>
        <value>86400</value>
    </property>
    <property>
        <name>yarn.log.server.url</name>
        <value>http://${NODE_X}:19888/jobhistory/job</value>
    </property>
    <property>
        <name>yarn.application.classpath</name>
        <value>
            /opt/hadoop/etc/hadoop:/opt/hadoop/share/hadoop/common/lib/*:/opt/hadoop/share/hadoop/common/*:/opt/hadoop/share/hadoop/hdfs:/opt/hadoop/share/hadoop/hdfs/lib/*:/opt/hadoop/share/hadoop/hdfs/*:/opt/hadoop/share/hadoop/mapreduce/lib/*:/opt/hadoop/share/hadoop/mapreduce/*:/opt/hadoop/share/hadoop/yarn/lib/*:/opt/hadoop/share/hadoop/yarn/*
        </value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>8</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>8192</value>
    </property>
    <property>
        <name>yarn.nodemanager.disk-health-checker.max-disk-utilization-per-disk-percentage</name>
        <value>98.5</value>
    </property>
    <property>
        <name>yarn.resourcemanager.cluster-id</name>
        <value>cluster1</value>
    </property>
    <property>
        <name>yarn.resourcemanager.ha.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.resourcemanager.ha.rm-ids</name>
        <value>rm1,rm2</value>
    </property>
    <property>
        <name>ha.zookeeper.quorum</name>
        <value>${NODE_X}:2181,${NODE_Y}:2181,${NODE_Z}:2181</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname.rm1</name>
        <value>${NODE_X}</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname.rm2</name>
        <value>${NODE_Y}</value>
    </property>
    <property>
        <name>yarn.resourcemanager.zk-address</name>
        <value>${NODE_X}:2181,${NODE_Y}:2181,${NODE_Z}:2181</value>
    </property>
    <property>
        <name>yarn.resourcemanager.zk-state-store.address</name>
        <value>${NODE_X}:2181,${NODE_Y}:2181,${NODE_Z}:2181</value>
    </property>
    <property>
        <name>yarn.resourcemanager.ha.automatic-failover.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.resourcemanager.store.class</name>
        <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value>
    </property>
    <property>
        <name>yarn.resourcemanager.recovery.enabled</name>
        <value>true</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address.rm1</name>
        <value>${NODE_X}:8088</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address.rm2</name>
        <value>${NODE_Y}:8088</value>
    </property>
    <property>
        <name>yarn.client.failover-proxy-provider</name>
        <value>org.apache.hadoop.yarn.client.ConfiguredRMFailoverProxyProvider</value>
    </property>
    <property>
        <name>yarn.resourcemanager.ha.automatic-failover.zk-base-path</name>
        <value>/yarn-leader-election</value>
        <description>Optionalsetting.Thedefaultvalueis/yarn-leader-election</description>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.class</name>
        <value>org.apache.hadoop.yarn.server.resourcemanager.scheduler.fair.FairScheduler</value>
    </property>
</configuration>
EOF

# Copy hadoop-env.sh
cp ${INSTALL_DIR}/hadoop-env.sh ${OPT}/hadoop/etc/hadoop/hadoop-env.sh

# Create necessary directories
rm -rf /opt/hadoop/tmp
rm -rf /opt/hadoop/hdfs/name
rm -rf /opt/hadoop/hdfs/data

mkdir -p /opt/hadoop/tmp
mkdir -p /opt/hadoop/hdfs/name
mkdir -p /opt/hadoop/hdfs/data