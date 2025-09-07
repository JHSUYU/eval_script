#!/bin/bash

# 分布式系统集群监控脚本 - 支持Cassandra、HDFS、HBase和YARN
# 使用top获取CPU，jstat获取内存

# ========== 配置 ==========
SERVERS=(
    "10.10.1.1"
    "10.10.1.2"
    "10.10.1.3"
    "10.10.1.4"
    "10.10.1.5"
    # 添加更多服务器...
)

SSH_USER="ZhenyuLi"
INTERVAL=1

# ========== 函数 ==========

# 获取Cassandra进程PID
get_cassandra_pid() {
    local server=$1
    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        'ps aux | grep "org.apache.cassandra.service.CassandraDaemon" | grep -v grep | awk "{print \$2}" | head -1'
}

# 获取HDFS进程PID (NameNode或DataNode)
get_hdfs_pid() {
    local server=$1
    local process_name=$2

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "jps | grep '$process_name' | awk '{print \$1}' | head -1"
}

# 获取HBase进程PID (HMaster或HRegionServer)
get_hbase_pid() {
    local server=$1
    local process_name=$2

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "jps | grep '$process_name' | awk '{print \$1}' | head -1"
}

# 获取YARN进程PID (ResourceManager或NodeManager)
get_yarn_pid() {
    local server=$1
    local process_name=$2

    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "jps | grep '$process_name' | awk '{print \$1}' | head -1"
}

# 获取单个进程的CPU和内存信息
get_process_metrics() {
    local server=$1
    local pid=$2
    local process_label=$3

    if [ -z "$pid" ]; then
        echo "N/A N/A"
        return
    fi

    # 使用 top 获取 CPU，jstat 获取内存
    local result=$(ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        "CPU=\$(top -b -n 1 -p $pid 2>/dev/null | tail -1 | awk '{print \$9}'); \
         JSTAT_GC=\$(jstat -gc $pid 2>/dev/null | tail -1); \
         if [ ! -z \"\$JSTAT_GC\" ]; then \
             HEAP_USED=\$(echo \"\$JSTAT_GC\" | awk '{printf \"%.1f\", (\$3+\$4+\$6+\$8)/1024}'); \
         else \
             HEAP_USED=\"N/A\"; \
         fi; \
         echo \"\$CPU \$HEAP_USED\"")

    echo "$result"
}

# ========== 监控Cassandra ==========
monitor_cassandra() {
    echo "Starting Cassandra cluster monitoring..."
    echo "Press Ctrl+C to stop"
    echo ""

    # 获取所有服务器的Cassandra PID
    declare -A SERVER_PIDS
    echo "Detecting Cassandra processes..."
    for server in "${SERVERS[@]}"; do
        pid=$(get_cassandra_pid "$server")
        if [ -z "$pid" ]; then
            echo "  ✗ $server: No Cassandra process found"
            SERVER_PIDS[$server]=""
        else
            echo "  ✓ $server: Cassandra PID=$pid"
            SERVER_PIDS[$server]=$pid
        fi
    done
    echo ""

    # 打印表头
    printf "%-12s %-15s %-12s %10s %15s\n" "Time" "Server" "Service" "CPU(%)" "Memory(MB)"
    printf "%-12s %-15s %-12s %10s %15s\n" "------------" "---------------" "------------" "----------" "---------------"

    # 持续监控
    while true; do
        TIMESTAMP=$(date +"%H:%M:%S")

        for server in "${SERVERS[@]}"; do
            pid=${SERVER_PIDS[$server]}

            if [ -z "$pid" ]; then
                printf "%-12s %-15s %-12s %10s %15s\n" "$TIMESTAMP" "$server" "Cassandra" "N/A" "N/A"
            else
                metrics=$(get_process_metrics "$server" "$pid" "Cassandra")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-12s %10s %15s\n" "$TIMESTAMP" "$server" "Cassandra" "$cpu" "$mem"
            fi
        done

        echo ""
        sleep $INTERVAL
    done
}

# ========== 监控HDFS ==========
monitor_hdfs() {
    echo "Starting HDFS cluster monitoring..."
    echo "Press Ctrl+C to stop"
    echo ""

    # 获取所有服务器的NameNode和DataNode PID
    declare -A NAMENODE_PIDS
    declare -A DATANODE_PIDS

    echo "Detecting HDFS processes..."
    for server in "${SERVERS[@]}"; do
        nn_pid=$(get_hdfs_pid "$server" "NameNode")
        dn_pid=$(get_hdfs_pid "$server" "DataNode")

        if [ -z "$nn_pid" ] && [ -z "$dn_pid" ]; then
            echo "  ✗ $server: No HDFS processes found"
        else
            [ ! -z "$nn_pid" ] && echo "  ✓ $server: NameNode PID=$nn_pid"
            [ ! -z "$dn_pid" ] && echo "  ✓ $server: DataNode PID=$dn_pid"
        fi

        NAMENODE_PIDS[$server]=$nn_pid
        DATANODE_PIDS[$server]=$dn_pid
    done
    echo ""

    # 打印表头
    printf "%-12s %-15s %-12s %10s %15s\n" "Time" "Server" "Service" "CPU(%)" "Memory(MB)"
    printf "%-12s %-15s %-12s %10s %15s\n" "------------" "---------------" "------------" "----------" "---------------"

    # 持续监控
    while true; do
        TIMESTAMP=$(date +"%H:%M:%S")

        for server in "${SERVERS[@]}"; do
            # 监控NameNode
            nn_pid=${NAMENODE_PIDS[$server]}
            if [ ! -z "$nn_pid" ]; then
                metrics=$(get_process_metrics "$server" "$nn_pid" "NameNode")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-12s %10s %15s\n" "$TIMESTAMP" "$server" "NameNode" "$cpu" "$mem"
            fi

            # 监控DataNode
            dn_pid=${DATANODE_PIDS[$server]}
            if [ ! -z "$dn_pid" ]; then
                metrics=$(get_process_metrics "$server" "$dn_pid" "DataNode")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-12s %10s %15s\n" "$TIMESTAMP" "$server" "DataNode" "$cpu" "$mem"
            fi
        done

        echo ""
        sleep $INTERVAL
    done
}

# ========== 监控HBase ==========
monitor_hbase() {
    echo "Starting HBase cluster monitoring..."
    echo "Press Ctrl+C to stop"
    echo ""

    # 获取所有服务器的HMaster和HRegionServer PID
    declare -A HMASTER_PIDS
    declare -A HREGIONSERVER_PIDS

    echo "Detecting HBase processes..."
    for server in "${SERVERS[@]}"; do
        hm_pid=$(get_hbase_pid "$server" "HMaster")
        hrs_pid=$(get_hbase_pid "$server" "HRegionServer")

        if [ -z "$hm_pid" ] && [ -z "$hrs_pid" ]; then
            echo "  ✗ $server: No HBase processes found"
        else
            [ ! -z "$hm_pid" ] && echo "  ✓ $server: HMaster PID=$hm_pid"
            [ ! -z "$hrs_pid" ] && echo "  ✓ $server: HRegionServer PID=$hrs_pid"
        fi

        HMASTER_PIDS[$server]=$hm_pid
        HREGIONSERVER_PIDS[$server]=$hrs_pid
    done
    echo ""

    # 打印表头
    printf "%-12s %-15s %-15s %10s %15s\n" "Time" "Server" "Service" "CPU(%)" "Memory(MB)"
    printf "%-12s %-15s %-15s %10s %15s\n" "------------" "---------------" "---------------" "----------" "---------------"

    # 持续监控
    while true; do
        TIMESTAMP=$(date +"%H:%M:%S")

        for server in "${SERVERS[@]}"; do
            # 监控HMaster
            hm_pid=${HMASTER_PIDS[$server]}
            if [ ! -z "$hm_pid" ]; then
                metrics=$(get_process_metrics "$server" "$hm_pid" "HMaster")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-15s %10s %15s\n" "$TIMESTAMP" "$server" "HMaster" "$cpu" "$mem"
            fi

            # 监控HRegionServer
            hrs_pid=${HREGIONSERVER_PIDS[$server]}
            if [ ! -z "$hrs_pid" ]; then
                metrics=$(get_process_metrics "$server" "$hrs_pid" "HRegionServer")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-15s %10s %15s\n" "$TIMESTAMP" "$server" "HRegionServer" "$cpu" "$mem"
            fi
        done

        echo ""
        sleep $INTERVAL
    done
}

# ========== 监控YARN ==========
monitor_yarn() {
    echo "Starting YARN cluster monitoring..."
    echo "Press Ctrl+C to stop"
    echo ""

    # 获取所有服务器的ResourceManager和NodeManager PID
    declare -A RESOURCEMANAGER_PIDS
    declare -A NODEMANAGER_PIDS

    echo "Detecting YARN processes..."
    for server in "${SERVERS[@]}"; do
        rm_pid=$(get_yarn_pid "$server" "ResourceManager")
        nm_pid=$(get_yarn_pid "$server" "NodeManager")

        if [ -z "$rm_pid" ] && [ -z "$nm_pid" ]; then
            echo "  ✗ $server: No YARN processes found"
        else
            [ ! -z "$rm_pid" ] && echo "  ✓ $server: ResourceManager PID=$rm_pid"
            [ ! -z "$nm_pid" ] && echo "  ✓ $server: NodeManager PID=$nm_pid"
        fi

        RESOURCEMANAGER_PIDS[$server]=$rm_pid
        NODEMANAGER_PIDS[$server]=$nm_pid
    done
    echo ""

    # 打印表头
    printf "%-12s %-15s %-18s %10s %15s\n" "Time" "Server" "Service" "CPU(%)" "Memory(MB)"
    printf "%-12s %-15s %-18s %10s %15s\n" "------------" "---------------" "------------------" "----------" "---------------"

    # 持续监控
    while true; do
        TIMESTAMP=$(date +"%H:%M:%S")

        for server in "${SERVERS[@]}"; do
            # 监控ResourceManager
            rm_pid=${RESOURCEMANAGER_PIDS[$server]}
            if [ ! -z "$rm_pid" ]; then
                metrics=$(get_process_metrics "$server" "$rm_pid" "ResourceManager")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-18s %10s %15s\n" "$TIMESTAMP" "$server" "ResourceManager" "$cpu" "$mem"
            fi

            # 监控NodeManager
            nm_pid=${NODEMANAGER_PIDS[$server]}
            if [ ! -z "$nm_pid" ]; then
                metrics=$(get_process_metrics "$server" "$nm_pid" "NodeManager")
                read cpu mem <<< "$metrics"
                printf "%-12s %-15s %-18s %10s %15s\n" "$TIMESTAMP" "$server" "NodeManager" "$cpu" "$mem"
            fi
        done

        echo ""
        sleep $INTERVAL
    done
}

# ========== 主程序 ==========
main() {
    # 检查参数
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <service>"
        echo "  service: cassandra, hdfs, hbase or yarn"
        exit 1
    fi

    SERVICE=$1

    case $SERVICE in
        cassandra)
            monitor_cassandra
            ;;
        hdfs)
            monitor_hdfs
            ;;
        hbase)
            monitor_hbase
            ;;
        yarn)
            monitor_yarn
            ;;
        *)
            echo "Error: Unknown service '$SERVICE'"
            echo "Supported services: cassandra, hdfs, hbase, yarn"
            exit 1
            ;;
    esac
}

# 捕获Ctrl+C信号
trap 'echo -e "\nMonitoring stopped."; exit 0' SIGINT SIGTERM

# 运行主程序
main "$@"