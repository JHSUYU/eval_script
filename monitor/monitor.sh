#!/bin/bash

# Distributed System Monitoring with JVMTop
# Supports: Cassandra, HDFS, HBase, YARN, ZooKeeper

# ========== Configuration ==========
SERVERS=(
    "10.10.1.1"
    "10.10.1.2"
    "10.10.1.3"
    "10.10.1.4"
    "10.10.1.5"
)

SSH_USER="ZhenyuLi"
JVMTOP_PATH="~/jvmtop-0.8.0"
MONITOR_DIR="~/monitor"
LOGS_DIR="${MONITOR_DIR}/logs"
PROCESSED_DIR="${MONITOR_DIR}/processed"
INTERVAL=1

# ========== Functions ==========

# Ensure directories exist
setup_directories() {
    for server in "${SERVERS[@]}"; do
        ssh -q ${SSH_USER}@${server} "mkdir -p ${LOGS_DIR} ${PROCESSED_DIR}"
    done
    mkdir -p logs processed results reports
}

# Get Cassandra PID
get_cassandra_pid() {
    local server=$1
    ssh -q -o ConnectTimeout=2 -o LogLevel=ERROR ${SSH_USER}@${server} 2>/dev/null \
        'ps aux | grep "org.apache.cassandra.service.CassandraDaemon" | grep -v grep | awk "{print \$2}" | head -1'
}


# Get HDFS PIDs
get_hdfs_pids() {
    local server=$1
    local pids=""

    # NameNode
    local nn_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep NameNode | awk '{print \$1}' | head -1")
    [ ! -z "$nn_pid" ] && pids="${pids}NameNode:${nn_pid} "

    # DataNode
    local dn_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep DataNode | awk '{print \$1}' | head -1")
    [ ! -z "$dn_pid" ] && pids="${pids}DataNode:${dn_pid} "

    echo "$pids"
}

# Get HBase PIDs
get_hbase_pids() {
    local server=$1
    local pids=""

    # HMaster
    local hm_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep HMaster | awk '{print \$1}' | head -1")
    [ ! -z "$hm_pid" ] && pids="${pids}HMaster:${hm_pid} "

    # HRegionServer
    local hrs_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep HRegionServer | awk '{print \$1}' | head -1")
    [ ! -z "$hrs_pid" ] && pids="${pids}HRegionServer:${hrs_pid} "

    echo "$pids"
}

# Get YARN PIDs
get_yarn_pids() {
    local server=$1
    local pids=""

    # ResourceManager
    local rm_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep ResourceManager | awk '{print \$1}' | head -1")
    [ ! -z "$rm_pid" ] && pids="${pids}ResourceManager:${rm_pid} "

    # NodeManager
    local nm_pid=$(ssh -q ${SSH_USER}@${server} "jps | grep NodeManager | awk '{print \$1}' | head -1")
    [ ! -z "$nm_pid" ] && pids="${pids}NodeManager:${nm_pid} "

    echo "$pids"
}

# Start monitoring on a single server
# start_monitor_on_server() {
#    local server=$1
#    local service=$2
#    local process_name=$3
#    local pid=$4
#    local log_file="${LOGS_DIR}/${server}_${service}_${process_name}_raw.log"
#
#    echo "  Starting monitor for ${process_name} (PID: ${pid}) on ${server}"
#
#    # Create monitoring script on remote server
#    ssh -q ${SSH_USER}@${server} "cat > ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh" << 'EOF'
##!/bin/zsh
#JVMTOP_PATH=$1
#PID=$2
#LOG_FILE=$3
#
#cd ${JVMTOP_PATH}
#chmod +x jvmtop.sh
#while sleep 1; do
#    ./jvmtop.sh ${PID} -n1 | grep --line-buffered "CPU:" >> ${LOG_FILE}
#done
#EOF
#
#
#
#    # Make it executable and run in background
#    ssh -q ${SSH_USER}@${server} "chmod +x ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh && \
#         ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh ${JVMTOP_PATH} ${pid} ${log_file}  2>&1 & \
#        echo \$! > ${MONITOR_DIR}/monitor_${process_name}_${pid}.pid"
#}

start_monitor_on_server() {
    local server=$1
    local service=$2
    local process_name=$3
    local pid=$4
    local log_file="${LOGS_DIR}/${server}_${service}_${process_name}_raw.log"

    echo "  Starting monitor for ${process_name} (PID: ${pid}) on ${server}"

    # Create monitoring script on remote server
    ssh -q ${SSH_USER}@${server} "cat > ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh" << 'EOF'
#!/bin/bash
JVMTOP_PATH=$1
PID=$2
LOG_FILE=$3

# Source user profile to get environment variables
[ -f ~/.bashrc ] && source ~/.bashrc
[ -f ~/.profile ] && source ~/.profile
[ -f ~/.zshrc] && source ~/.zshrc

# Set JAVA_HOME if not set
if [ -z "$JAVA_HOME" ]; then
    if [ -d "/usr/lib/jvm/java-8-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"
    elif [ -d "/usr/lib/jvm/java-11-openjdk-amd64" ]; then
        export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-amd64"
    fi
fi

cd ${JVMTOP_PATH}
chmod +x jvmtop.sh

# Main monitoring loop
while sleep 1; do
    # Run jvmtop and capture the output line with the PID
    ./jvmtop.sh ${PID} -n1 | grep --line-buffered "CPU:" >> ${LOG_FILE}
done
EOF

    # Make it executable and run in background
    ssh -q ${SSH_USER}@${server} "chmod +x ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh && \
        nohup ${MONITOR_DIR}/monitor_${process_name}_${pid}.sh ${JVMTOP_PATH} ${pid} ${log_file} > /dev/null 2>&1 & \
        echo \$! > ${MONITOR_DIR}/monitor_${process_name}_${pid}.pid"
}

# Stop all monitors on a server
stop_monitors_on_server() {
    local server=$1

    echo "Stopping monitors on ${server}..."
    ssh -q ${SSH_USER}@${server} "
        for pidfile in ${MONITOR_DIR}/monitor_*.pid; do
            if [ -f \"\$pidfile\" ]; then
                kill \$(cat \"\$pidfile\") 2>/dev/null
                rm -f \"\$pidfile\"
            fi
        done
        rm -f ${MONITOR_DIR}/monitor_*.sh
    "
}

# Deploy monitor tools to server
deploy_monitor_tools() {
    local server=$1

    echo "Deploying monitor tools to ${server}..."

    # Copy the monitor_tools.py to remote server
    scp -q monitor_tools.py ${SSH_USER}@${server}:${MONITOR_DIR}/

    if [ $? -eq 0 ]; then
        echo "  ✓ Tools deployed successfully"
    else
        echo "  ✗ Failed to deploy tools"
        return 1
    fi
}

# Process logs for a service
process_logs() {
    local service=$1

    echo "Processing logs for ${service}..."

    for server in "${SERVERS[@]}"; do
        # Copy raw logs from remote servers
        scp -q ${SSH_USER}@${server}:${LOGS_DIR}/${server}_${service}_*_raw.log logs/ 2>/dev/null || true
    done

    # Process all raw logs for this service
    python3 monitor_tools.py process ${service}
}

# Monitor Cassandra
monitor_cassandra() {
    echo "Starting Cassandra monitoring..."

    for server in "${SERVERS[@]}"; do
        pid=$(get_cassandra_pid "$server")
        if [ ! -z "$pid" ]; then
            start_monitor_on_server "$server" "cassandra" "Cassandra" "$pid"
        else
            echo "  ✗ No Cassandra process found on ${server}"
        fi
    done
}

# Monitor ZooKeeper
monitor_zookeeper() {
    echo "Starting ZooKeeper monitoring..."

    for server in "${SERVERS[@]}"; do
        pid=$(get_zookeeper_pid "$server")
        if [ ! -z "$pid" ]; then
            start_monitor_on_server "$server" "zookeeper" "ZooKeeper" "$pid"
        else
            echo "  ✗ No ZooKeeper process found on ${server}"
        fi
    done
}

# Monitor HDFS
monitor_hdfs() {
    echo "Starting HDFS monitoring..."

    for server in "${SERVERS[@]}"; do
        pids=$(get_hdfs_pids "$server")
        if [ ! -z "$pids" ]; then
            for entry in $pids; do
                IFS=':' read -r process_name pid <<< "$entry"
                start_monitor_on_server "$server" "hdfs" "$process_name" "$pid"
            done
        else
            echo "  ✗ No HDFS processes found on ${server}"
        fi
    done
}

# Monitor HBase
monitor_hbase() {
    echo "Starting HBase monitoring..."

    for server in "${SERVERS[@]}"; do
        pids=$(get_hbase_pids "$server")
        if [ ! -z "$pids" ]; then
            for entry in $pids; do
                IFS=':' read -r process_name pid <<< "$entry"
                start_monitor_on_server "$server" "hbase" "$process_name" "$pid"
            done
        else
            echo "  ✗ No HBase processes found on ${server}"
        fi
    done
}

# Monitor YARN
monitor_yarn() {
    echo "Starting YARN monitoring..."

    for server in "${SERVERS[@]}"; do
        pids=$(get_yarn_pids "$server")
        if [ ! -z "$pids" ]; then
            for entry in $pids; do
                IFS=':' read -r process_name pid <<< "$entry"
                start_monitor_on_server "$server" "yarn" "$process_name" "$pid"
            done
        else
            echo "  ✗ No YARN processes found on ${server}"
        fi
    done
}

# Stop all monitoring
stop_all() {
    echo "Stopping all monitors..."
    for server in "${SERVERS[@]}"; do
        stop_monitors_on_server "$server"
    done
}

# Deploy tools to all servers
deploy_all() {
    echo "Deploying monitor tools to all servers..."

    if [ ! -f "monitor_tools.py" ]; then
        echo "Error: monitor_tools.py not found in current directory"
        exit 1
    fi

    for server in "${SERVERS[@]}"; do
        deploy_monitor_tools "$server"
    done
}

# Clean logs function
clean_logs() {
    echo "Cleaning logs..."

    # Clean local logs
    echo "  Cleaning local logs directory..."
    rm -f logs/* 2>/dev/null
    echo "    ✓ Local logs cleaned"

    # Clean remote logs on all servers
    echo "  Cleaning remote logs on all servers..."
    for server in "${SERVERS[@]}"; do
        echo "    Cleaning logs on ${server}..."
        ssh -q ${SSH_USER}@${server} "rm -f ${LOGS_DIR}/* 2>/dev/null" || {
            echo "      ✗ Failed to clean logs on ${server}"
            continue
        }
        echo "      ✓ Logs cleaned on ${server}"
    done

    echo "All logs cleaned successfully."
}

# Main function
main() {
  cd ~/monitor
    case "$1" in
        start)
            if [ -z "$2" ]; then
                echo "Usage: $0 start <service|all>"
                echo "Services: cassandra, zookeeper, hdfs, hbase, yarn, all"
                exit 1
            fi

            setup_directories
            deploy_all

            case "$2" in
                cassandra) monitor_cassandra ;;
                zookeeper) monitor_zookeeper ;;
                hdfs) monitor_hdfs ;;
                hbase) monitor_hbase ;;
                yarn) monitor_yarn ;;
                all)
                    monitor_cassandra
                    monitor_zookeeper
                    monitor_hdfs
                    monitor_hbase
                    monitor_yarn
                    ;;
                *)
                    echo "Unknown service: $2"
                    exit 1
                    ;;
            esac

            echo ""
            echo "Monitoring started. Use '$0 stop' to stop monitoring."
            echo "Use '$0 process <service>' to process logs."
            ;;

        stop)
            stop_all
            echo "All monitors stopped."
            ;;

        process)
            if [ -z "$2" ]; then
                echo "Usage: $0 process <service|all>"
                exit 1
            fi

            mkdir -p results reports

            case "$2" in
                cassandra|zookeeper|hdfs|hbase|yarn)
                    process_logs "$2"
                    ;;
                all)
                    for service in cassandra zookeeper hdfs hbase yarn; do
                        process_logs "$service"
                    done
                    ;;
                *)
                    echo "Unknown service: $2"
                    exit 1
                    ;;
            esac

            echo "Processing complete"
            ;;

         clean)
            clean_logs
         ;;

        *)
            echo "Usage: $0 {start|stop|process|analyze} [service]"
            echo "Services: cassandra, zookeeper, hdfs, hbase, yarn, all"
            exit 1
            ;;
    esac
}

# Trap Ctrl+C
trap 'echo "Interrupted. Stopping monitors..."; stop_all; exit 0' SIGINT SIGTERM

# Run main
main "$@"