# JVMTop分布式系统监控工具

基于JVMTop的分布式Java系统监控解决方案，提供精确的JVM性能指标采集与分析。

## 概述

本监控系统使用JVMTop对分布式Java系统进行实时CPU和内存监控，支持以下系统：
- Apache Cassandra
- Apache ZooKeeper
- HDFS (NameNode, DataNode)
- HBase (HMaster, HRegionServer)
- YARN (ResourceManager, NodeManager)
- Solr

## 文件结构

```
/monitor/
├── monitor.sh          # 主监控脚本
├── setup.sh           # JVMTop安装脚本  
├── monitor_tools.py   # 统一的Python处理工具
└── README.md         # 本文档
```


## 安装步骤

### 1. 准备环境

```上传remote server上：

./upload.sh ZhenyuLi@ms1238.utah.cloudlab.us
```

### 2. 配置服务器列表

编辑 `monitor.sh` 文件：

```bash
# 修改服务器列表
SERVERS=(
    "10.10.1.1"
    "10.10.1.2"
    "10.10.1.3"
    # 添加更多服务器...
)

# 设置SSH用户名
SSH_USER="your_username" (by default is ZhenyuLi)
```

### 3. 安装JVMTop

```bash
# 在所有服务器上自动安装JVMTop
cd ~/monitor
chmod +x setup.sh
./setup.sh
```

## 使用方法

### 启动监控

每次启动前都要运行./monitor.sh clean
运行后一定要./monitor.sh stop清理监控线程

```bash
# 监控单个服务
./monitor.sh start cassandra
./monitor.sh start zookeeper
./monitor.sh start hdfs
./monitor.sh start hbase
./monitor.sh start yarn

# 监控所有服务
./monitor.sh start all
```

### 停止监控

```bash
./monitor.sh stop
```

### 处理日志

运行工作负载后：

```bash
# 处理单个服务的日志
./monitor.sh process cassandra/hbase/yarn

```