#!/bin/bash

# Git仓库地址
GIT_REPO="https://github.com/JHSUYU/Solr.git"
SOLR_DIR="/opt/Solr"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示开始信息
echo "Starting Git clone/update and build process..."
echo "================================================"

#检查Solr目录是否存在
if [ ! -d "${SOLR_DIR}" ]; then
    echo "Solr directory not found. Cloning repository..."
    cd /opt
    git clone ${GIT_REPO}
    echo "✓ Repository cloned successfully"
else
    echo "Solr directory exists. Pulling latest changes..."
    cd ${SOLR_DIR}

    # 保存当前更改（如果有）
#    if ! git diff --quiet || ! git diff --staged --quiet; then
#        echo "Warning: Local changes detected, stashing them..."
#        git stash
#    fi

    # 强制拉取最新更改
    git fetch --all
    git reset --hard origin/master  # 假设主分支是master
    echo "✓ Repository updated to latest version"
fi

#构建Solr
echo "Building Solr..."
cd ${SOLR_DIR}

# 编译主项目
echo "Running ant compile..."
ant clean && ant compile

# 构建服务器
echo "Building Solr server..."
cd solr/
ant server

