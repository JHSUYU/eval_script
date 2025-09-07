#!/bin/bash

# 配置变量
USER="ZhenyuLi"
HOSTS=("ms1132.utah.cloudlab.us" "ms1101.utah.cloudlab.us")
IPS=("10.10.1.1" "10.10.1.2")
SOLR_BIN="/opt/Solr/solr/bin/solr"
COLLECTION="mycollection"
ZK_HOSTS="10.10.1.1:2181,10.10.1.2:2181,10.10.1.3:2181"

# 函数：识别leader节点
find_leader() {
    echo "=== 识别leader节点 ==="

    # 获取集群状态
    CLUSTER_STATUS=$(curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}")

    # 如果第一个节点无响应，尝试第二个
    if [ -z "$CLUSTER_STATUS" ]; then
        CLUSTER_STATUS=$(curl -s "http://${IPS[1]}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}")
    fi

    # 解析leader信息
    for replica in $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas | keys[]"); do
        IS_LEADER=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.leader // false")

        if [ "$IS_LEADER" = "true" ]; then
            LEADER_CORE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.core")
            NODE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.node_name")
            LEADER_IP=$(echo "$NODE" | cut -d':' -f1)

            # 找到对应的host
            for i in "${!IPS[@]}"; do
                if [ "${IPS[$i]}" = "$LEADER_IP" ]; then
                    LEADER_HOST="${HOSTS[$i]}"
                    break
                fi
            done

            echo "Leader节点: $LEADER_HOST ($LEADER_IP)"
            echo "Leader Core: $LEADER_CORE"
            return 0
        fi
    done

    echo "❌ 无法找到leader节点"
    return 1
}

# 函数：kill leader节点
kill_leader() {
    echo "=== 停止Leader节点 ==="
    echo "正在停止 $LEADER_HOST 上的Solr..."
    ssh "$USER@$LEADER_HOST" "$SOLR_BIN stop -all"

    # 验证节点已停止
    sleep 3
    if ssh "$USER@$LEADER_HOST" "ps aux | grep -v grep | grep 'start.jar.*8983'" > /dev/null 2>&1; then
        echo "⚠️  节点可能未完全停止，强制kill..."
        ssh "$USER@$LEADER_HOST" "ps aux | grep 'start.jar.*8983' | grep -v grep | awk '{print \$2}' | xargs kill -9" 2>/dev/null
    fi

    echo "✅ Leader节点已停止"
}

# 函数：重启leader节点
restart_leader() {
    echo "=== 重启Leader节点 ==="
    echo "正在启动 $LEADER_HOST 上的Solr..."
    ssh "$USER@$LEADER_HOST" "$SOLR_BIN start -c -z $ZK_HOSTS -p 8983 -h $LEADER_IP -s /opt/SolrData -m 8g"

    # 等待节点完全启动
    echo "等待节点启动..."
    for i in {1..30}; do
        if curl -s "http://${LEADER_IP}:8983/solr/admin/info/system" > /dev/null 2>&1; then
            echo "✅ Leader节点已启动"
            return 0
        fi
        echo -ne "\r等待中... $i/30"
        sleep 1
    done

    echo "⚠️  节点启动可能存在问题"
    return 1
}

# 函数：检查集群状态
check_cluster_status() {
    echo "=== 检查集群状态 ==="

    # 获取存活的节点IP
    ACTIVE_IP=""
    for ip in "${IPS[@]}"; do
        if curl -s "http://${ip}:8983/solr/admin/info/system" > /dev/null 2>&1; then
            ACTIVE_IP=$ip
            break
        fi
    done

    if [ -z "$ACTIVE_IP" ]; then
        echo "❌ 无法连接到任何节点"
        return 1
    fi

    # 获取集群状态
    CLUSTER_STATUS=$(curl -s "http://${ACTIVE_IP}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}")

    # 显示各节点状态
    echo "节点状态:"
    for replica in $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas | keys[]"); do
        NODE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.node_name")
        STATE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.state")
        IS_LEADER=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.leader // false")

        if [ "$IS_LEADER" = "true" ]; then
            echo "  - $NODE: $STATE (LEADER)"
        else
            echo "  - $NODE: $STATE"
        fi
    done
}

# 主流程
main() {
    echo "========================================="
    echo "Leader节点重启测试脚本"
    echo "========================================="
    echo "配置信息:"
    echo "  Collection: $COLLECTION"
    echo "  节点: ${HOSTS[*]}"
    echo "========================================="

    # 第一次操作
    echo -e "\n📍 第一次操作"
    echo "========================================="

    # 找到leader
    if ! find_leader; then
        echo "❌ 无法继续，退出脚本"
        exit 1
    fi

    # Kill leader
    kill_leader

    # 等待10秒
    echo -e "\n⏳ 等待10秒..."
    sleep 10

    # 重启leader
    restart_leader

    # 检查集群状态
    check_cluster_status

    sleep 40

    # 等待1分钟
    echo ""

    # 第二次操作
    echo -e "\n📍 第二次操作"
    echo "========================================="

    # 重新找到leader（可能已经变化）
    if ! find_leader; then
        echo "❌ 无法继续，退出脚本"
        exit 1
    fi

    # Kill leader
    kill_leader

    # 等待10秒
    echo -e "\n⏳ 等待10秒..."
    sleep 10

    # 重启leader
    restart_leader

    # 最终检查集群状态
    echo -e "\n=== 最终集群状态 ==="
    check_cluster_status

    echo -e "\n✅ 测试完成"
}

# 执行主流程
main