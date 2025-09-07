#!/bin/bash

# Solr集群监控脚本 - 简化版
# 使用ps获取CPU，jstat获取内存
# 监控时长：60秒

# ========== 配置 ==========
SERVERS=(
    "10.10.1.1"
    "10.10.1.2"
    # 添加更多服务器...
)

SSH_USER="ZhenyuLi"
SOLR_PORT=8983
MONITOR_DURATION=60
INTERVAL=1
LOG_DIR="/opt/solr_monitor_$(date +%Y%m%d_%H%M%S)"

# ========== 函数 ==========

# 执行远程命令
remote_exec() {
    local server=$1
    local command=$2
    ssh ${SSH_USER}@${server} "$command" 2>/dev/null
}

# 获取Solr进程PID
get_solr_pid() {
    local server=$1
    remote_exec "$server" "lsof -i:${SOLR_PORT} -sTCP:LISTEN 2>/dev/null | grep java | awk '{print \$2}' | head -1"
}

# 监控单个服务器
monitor_server() {
    local server=$1
    local pid=$(get_solr_pid "$server")

    if [ -z "$pid" ]; then
        echo "$(date +%H:%M:%S) $server: No Solr process found" >> "$LOG_DIR/error.log"
        return 1
    fi

    echo "Monitoring $server: PID=$pid"

    local memory_file="$LOG_DIR/${server}_memory.log"
    local cpu_file="$LOG_DIR/${server}_cpu.log"

    # 启动ps监控CPU（后台运行）
    ssh ${SSH_USER}@${server} bash << EOF > "$cpu_file" 2>/dev/null &
#!/bin/bash
PID=$pid
DURATION=$MONITOR_DURATION
INTERVAL=$INTERVAL

echo "# Time,CPU(%)"

SAMPLES=\$((DURATION / INTERVAL))
for ((i=1; i<=SAMPLES; i++)); do
    TIMESTAMP=\$(date +"%H:%M:%S")

    # 使用ps获取CPU使用率
    CPU=\$(ps -p \$PID -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    if [ ! -z "\$CPU" ]; then
        echo "\$TIMESTAMP,\$CPU"
    fi

    [ \$i -lt \$SAMPLES ] && sleep \$INTERVAL
done
EOF

    # 启动jstat监控内存（后台运行）
    ssh ${SSH_USER}@${server} bash << EOF > "$memory_file" 2>/dev/null &
#!/bin/bash
PID=$pid
DURATION=$MONITOR_DURATION
INTERVAL=$INTERVAL

echo "# Time,HeapUsed(MB),HeapMax(MB),NonHeap(MB),YGC,FGC"

SAMPLES=\$((DURATION / INTERVAL))
for ((i=1; i<=SAMPLES; i++)); do
    TIMESTAMP=\$(date +"%H:%M:%S")

    # 使用jstat获取内存数据
    JSTAT_GC=\$(jstat -gc \$PID 2>/dev/null | tail -1)
    if [ ! -z "\$JSTAT_GC" ]; then
        HEAP_USED=\$(echo "\$JSTAT_GC" | awk '{printf "%.1f", (\$3+\$4+\$6+\$8)/1024}')
        HEAP_MAX=\$(echo "\$JSTAT_GC" | awk '{printf "%.1f", (\$1+\$2+\$5+\$7)/1024}')
        META_USED=\$(echo "\$JSTAT_GC" | awk '{printf "%.1f", \$10/1024}')
        YGC=\$(echo "\$JSTAT_GC" | awk '{print \$11}')
        FGC=\$(echo "\$JSTAT_GC" | awk '{print \$13}')

        echo "\$TIMESTAMP,\$HEAP_USED,\$HEAP_MAX,\$META_USED,\$YGC,\$FGC"
    fi

    [ \$i -lt \$SAMPLES ] && sleep \$INTERVAL
done
EOF
}

# 生成报告
generate_summary() {
    echo ""
    echo "========================================"
    echo "Solr Cluster Monitoring Summary"
    echo "Time: $(date +"%Y-%m-%d %H:%M:%S")"
    echo "========================================"

    for server in "${SERVERS[@]}"; do
        local memory_file="$LOG_DIR/${server}_memory.log"
        local cpu_file="$LOG_DIR/${server}_cpu.log"
        local pid=$(get_solr_pid "$server")

        if [ ! -f "$memory_file" ] || [ ! -f "$cpu_file" ]; then
            echo "$server: NO DATA"
            continue
        fi

        # 计算CPU平均值（从ps输出提取）
        local cpu_avg=$(grep -v "^#" "$cpu_file" 2>/dev/null | awk -F',' '
            NR>0 && NF>=2 {cpu_sum+=$2; count++}
            END {if(count>0) printf "%.1f", cpu_sum/count; else print "0"}')

        # 计算内存平均值（从jstat输出提取）
        local mem_avg=$(grep -v "^#" "$memory_file" 2>/dev/null | awk -F',' '
            NR>0 && NF>=5 {heap_sum+=$2; count++}
            END {if(count>0) printf "%.1f", heap_sum/count; else print "0"}')

        echo "$server: CPU ${cpu_avg}%, Memory ${mem_avg} MB"
    done

    echo "========================================"
    echo "Logs saved in: $LOG_DIR"
}

# 主程序
main() {
    mkdir -p "$LOG_DIR"

    echo "Starting Solr cluster monitoring..."
    echo "Duration: ${MONITOR_DURATION}s"
    echo ""

    # 并行监控所有服务器
    for server in "${SERVERS[@]}"; do
        monitor_server "$server"
    done

    # 等待监控完成
    echo "Waiting for monitoring to complete..."
    sleep $((MONITOR_DURATION + 5))

    # 生成报告
    generate_summary
}

# 运行
main