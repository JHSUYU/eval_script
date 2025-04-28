#!/bin/bash

# 定义安装目录变量
INSTALL_DIR="/localtmp"

# 解压Zookeeper到安装目录
tar -xzf ${INSTALL_DIR}/hbase-2.5.12-SNAPSHOT-bin.tar.gz -C ${INSTALL_DIR}
rm -rf ${INSTALL_DIR}/hbase
mv ${INSTALL_DIR}/hbase-2.5.12-SNAPSHOT ${INSTALL_DIR}/hbase

# 复制配置文件
cp ${INSTALL_DIR}/hbase_scripts/slave_cluster/hbase-site.xml ${INSTALL_DIR}/hbase/conf/hbase-site.xml