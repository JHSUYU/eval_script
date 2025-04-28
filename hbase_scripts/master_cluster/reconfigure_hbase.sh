#!/bin/bash

# 定义安装目录变量
INSTALL_DIR="/opt/hbase_scripts"
OPT_DIR="/opt"

# 解压Zookeeper到安装目录
tar -xzf ${INSTALL_DIR}/hbase-2.5.12-SNAPSHOT-bin.tar.gz -C ${OPT_DIR}
rm -rf ${OPT_DIR}/hbase
mv ${OPT_DIR}/hbase-2.5.12-SNAPSHOT ${OPT_DIR}/hbase

# 复制配置文件
cp ${INSTALL_DIR}/hbase-site.xml ${OPT_DIR}/hbase/conf/hbase-site.xml