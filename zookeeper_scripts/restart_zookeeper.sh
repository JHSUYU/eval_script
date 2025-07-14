#!/bin/bash

# 定义变量
USER="ZhenyuLi"
HOSTS=(
  "ms0805.utah.cloudlab.us"
  "ms0832.utah.cloudlab.us"
  "ms0828.utah.cloudlab.us"
)

# 显示脚本开始信息
echo "=== ZooKeeper集群清理脚本 ==="
echo "将会清理以下节点的ZooKeeper数据:"
for host in "${HOSTS[@]}"; do
  echo "- $host"
done
echo ""

# 依次SSH到每个节点并执行ZooKeeper清理操作
for host in "${HOSTS[@]}"; do
  echo "======================================"
  echo "正在连接到 $host 并执行ZooKeeper清理"
  echo "======================================"

  # 创建远程执行的命令
  SSH_COMMAND='
    ZK_HOME="/opt/zookeeper"
    ZK_CMD="$ZK_HOME/bin/zkServer.sh"
    ZK_CFG="$ZK_HOME/conf/zoo.cfg"

    # 从配置文件中查找数据目录
    if [ -f "$ZK_CFG" ]; then
        DATA_DIR=$(grep "^dataDir=" "$ZK_CFG" | cut -d= -f2)
        LOGS_DIR=$(grep "^dataLogDir=" "$ZK_CFG" | cut -d= -f2)
    else
        echo "未找到ZooKeeper配置文件: $ZK_CFG"
        exit 1
    fi

    echo "ZooKeeper主目录: $ZK_HOME"
    echo "ZooKeeper数据目录: $DATA_DIR"
    if [ -n "$LOGS_DIR" ]; then
        echo "ZooKeeper日志目录: $LOGS_DIR"
    fi

    # 停止ZooKeeper服务
    echo "正在停止ZooKeeper服务..."
    $ZK_CMD stop

    # 等待ZooKeeper完全停止
    echo "等待ZooKeeper完全停止..."
    sleep 5

    # 使用ps -ef | grep zookeeper查找并终止ZooKeeper进程
    echo "正在查找ZooKeeper进程..."
    ZOOKEEPER_PIDS=$(ps -ef | grep zookeeper | grep -v grep | awk '\''{print $2}'\'')

    if [ -n "$ZOOKEEPER_PIDS" ]; then
        echo "发现ZooKeeper进程，PID列表: $ZOOKEEPER_PIDS"

        # 尝试正常终止进程
        echo "正在尝试正常终止进程..."
        for pid in $ZOOKEEPER_PIDS; do
            echo "终止进程 PID: $pid"
            sudo kill $pid
        done

        # 等待进程终止
        echo "等待进程终止..."
        sleep 5

        # 再次检查是否还有进程存在
        REMAINING_PIDS=$(ps -ef | grep zookeeper | grep -v grep | awk '\''{print $2}'\'')
        if [ -n "$REMAINING_PIDS" ]; then
            echo "ZooKeeper进程仍在运行，进行强制终止..."
            for pid in $REMAINING_PIDS; do
                echo "强制终止进程 PID: $pid"
                sudo kill -9 $pid
            done
            sleep 2

            # 最后检查
            FINAL_CHECK=$(ps -ef | grep zookeeper | grep -v grep)
            if [ -n "$FINAL_CHECK" ]; then
                echo "警告：仍有ZooKeeper进程无法终止："
                echo "$FINAL_CHECK"
            else
                echo "所有ZooKeeper进程已终止"
            fi
        else
            echo "所有ZooKeeper进程已终止"
        fi
    else
        echo "未发现运行中的ZooKeeper进程"
    fi

    # 删除ZooKeeper数据
    echo "正在清理ZooKeeper数据..."
    if [ -d "$DATA_DIR" ]; then
        # 备份myid文件（如果存在）
        if [ -f "$DATA_DIR/myid" ]; then
            MYID=$(cat "$DATA_DIR/myid")
            echo "已备份myid文件，节点ID为: $MYID"
        fi

        # 删除数据目录下的所有内容
        echo "删除数据目录内容: $DATA_DIR/*"
        rm -rf "$DATA_DIR"/*

        # 重建myid文件
        if [ -n "$MYID" ]; then
            echo "重建myid文件..."
            echo "$MYID" > "$DATA_DIR/myid"
            echo "myid文件已重建，内容: $MYID"
        fi
    else
        echo "警告：数据目录不存在: $DATA_DIR"
        mkdir -p "$DATA_DIR"
        echo "已创建数据目录: $DATA_DIR"
    fi

    # 清理日志目录
    if [ -n "$LOGS_DIR" ] && [ -d "$LOGS_DIR" ]; then
        echo "清理事务日志目录: $LOGS_DIR/*"
        rm -rf "$LOGS_DIR"/*
        echo "事务日志目录已清理"
    else
        echo "未配置单独的日志目录或目录不存在"
    fi

    echo "ZooKeeper环境已完全清理完毕"
  '

  # 使用SSH连接到远程主机并执行命令
  echo "正在SSH连接到 $host 执行清理操作..."
  ssh "$USER@$host" "$SSH_COMMAND"

  # 检查命令执行状态
  if [ $? -eq 0 ]; then
    echo "✅ 节点 $host 的ZooKeeper环境清理成功"
  else
    echo "❌ 错误：无法在节点 $host 上完成ZooKeeper环境清理"
  fi

  echo ""
done

echo "所有节点的ZooKeeper环境清理操作已完成"
echo "=== 开始重启所有ZooKeeper节点 ==="

# 重启所有ZooKeeper节点
for host in "${HOSTS[@]}"; do
  echo "正在启动 $host 上的ZooKeeper服务..."
  ssh "$USER@$host" "/opt/zookeeper/bin/zkServer.sh start"

  if [ $? -eq 0 ]; then
    echo "✅ 节点 $host 的ZooKeeper服务启动成功"
  else
    echo "❌ 错误：无法在节点 $host 上启动ZooKeeper服务"
  fi
done

echo "=== ZooKeeper集群重启完成 ==="
echo "集群清理并重启成功！"