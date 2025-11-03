#!/bin/bash

# 配置变量
USER="ZhenyuLi"
HOSTS=("clnode311.clemson.cloudlab.us" "clnode314.clemson.cloudlab.us")
IPS=("10.10.1.1" "10.10.1.2")
SOLR_BIN="/opt/Solr/solr/bin/solr"
COLLECTION="mycollection"

# 检查并安装 jq (Ubuntu)
check_and_install_jq() {
    if ! command -v jq &> /dev/null; then
        echo "jq 未安装，正在为 Ubuntu 系统安装..."
        sudo apt-get update
        sudo apt-get install -y jq

        # 验证安装
        if command -v jq &> /dev/null; then
            echo "✅ jq 安装成功，版本: $(jq --version)"
        else
            echo "❌ jq 安装失败，请手动运行: sudo apt-get install jq"
            exit 1
        fi
    else
        echo "✅ jq 已安装，版本: $(jq --version)"
    fi
}

# 在脚本开始时检查 jq
echo "=== 检查依赖项 ==="
check_and_install_jq

echo "=== Step 1: 创建collection (两个节点都活着) ==="
curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=2&collection.configName=myconfig"
sleep 5

echo -e "\n=== Step 2: 识别leader和follower ==="
CLUSTER_STATUS=$(curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}")

# 解析replica信息
for replica in $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas | keys[]"); do
  CORE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.core")
  NODE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.node_name")
  IS_LEADER=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.leader // false")

  if [ "$IS_LEADER" = "true" ]; then
    LEADER_CORE="$CORE"
    LEADER_IP=$(echo "$NODE" | cut -d':' -f1)
    echo "Leader: $LEADER_CORE @ $LEADER_IP"
  else
    FOLLOWER_CORE="$CORE"
    FOLLOWER_IP=$(echo "$NODE" | cut -d':' -f1)
    FOLLOWER_REPLICA="$replica"
    echo "Follower: $FOLLOWER_CORE @ $FOLLOWER_IP"

    # 确定follower的host
    for i in "${!IPS[@]}"; do
      if [ "${IPS[$i]}" = "$FOLLOWER_IP" ]; then
        FOLLOWER_HOST="${HOSTS[$i]}"
        break
      fi
    done
  fi
done

echo -e "\n=== Step 3: 添加初始文档 ==="
curl -X POST -H 'Content-Type: application/json' \
  "http://${LEADER_IP}:8983/solr/${COLLECTION}/update?commit=true" \
  --data-binary '[
    {"id": "1", "title": "文档1"},
    {"id": "2", "title": "文档2"}
  ]'

echo -e "\n=== Step 4: 停止follower节点 ==="
echo "停止 $FOLLOWER_HOST 上的Solr..."
ssh "$USER@$FOLLOWER_HOST" "$SOLR_BIN stop -p 8983"
sleep 5

# 验证follower已down
STATE=$(curl -s "http://${LEADER_IP}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}" | \
  jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${FOLLOWER_REPLICA}.state")
echo "Follower状态: $STATE"

echo -e "\n=== Step 5: 在leader上添加大量文档 (创造差异) ==="
# 添加1000个文档来超过PeerSync阈值
for i in {1..5}; do
  echo "批次 $i/10..."
  docs="["
  for j in {1..100}; do
    id=$((i*100+j))
    [ $j -gt 1 ] && docs+=","
    docs+="{\"id\":\"doc_${id}\",\"title\":\"文档${id}\"}"
  done
  docs+="]"

  curl -s -X POST -H 'Content-Type: application/json' \
    "http://${LEADER_IP}:8983/solr/${COLLECTION}/update?min_rf=1&commit=true" \
    --data-binary "$docs" > /dev/null
done

#BATCH_SIZE=100000  # 减小单批次大小
#TOTAL_BATCHES=500  # 增加批次数保持总量不变
#
#for i in $(seq 1 $TOTAL_BATCHES); do
#  echo "批次 $i/$TOTAL_BATCHES..."
#
#  # 使用printf和管道，避免字符串拼接
#  {
#    echo -n '['
#    for j in $(seq 1 $BATCH_SIZE); do
#      id=$((i*BATCH_SIZE+j))
#      [ $j -gt 1 ] && echo -n ','
#      printf '{"id":"doc_%d","title":"文档%d"}' $id $id
#    done
#    echo -n ']'
#  } | curl -s -X POST -H 'Content-Type: application/json' \
#    "http://${LEADER_IP}:8983/solr/${COLLECTION}/update?min_rf=1&commit=false" \
#    --data-binary @- > /dev/null
#done

curl "http://${LEADER_IP}:8983/solr/${COLLECTION}/update?commit=true"

echo -e "\n=== Step 6: 查看leader文档数 ==="
LEADER_COUNT=$(curl -s "http://${LEADER_IP}:8983/solr/${LEADER_CORE}/select?q=*:*&rows=0&distrib=false" | \
  jq -r '.response.numFound')
echo "Leader文档数: $LEADER_COUNT"

echo -e "\n=== Step 7: 重启follower节点 ==="
ssh "$USER@$FOLLOWER_HOST" "$SOLR_BIN start -c -z 10.10.1.1:2181,10.10.1.2:2181,10.10.1.3:2181 -p 8983 -h ${FOLLOWER_IP} -s /opt/SolrData -m 8g"
sleep 10

echo -e "\n=== Step 8: 查看恢复前的差异 ==="
FOLLOWER_COUNT=$(curl -s "http://${FOLLOWER_IP}:8983/solr/${FOLLOWER_CORE}/select?q=*:*&rows=0&distrib=false" | \
  jq -r '.response.numFound')
echo "Leader: $LEADER_COUNT, Follower: $FOLLOWER_COUNT"
echo "差异: $((LEADER_COUNT - FOLLOWER_COUNT)) 文档"

echo "curl http://${FOLLOWER_IP}:8983/solr/admin/cores?action=REQUESTRECOVERY&core=${FOLLOWER_CORE}"
#echo -e "\n=== Step 9: 触发recovery ==="
#curl "http://${FOLLOWER_IP}:8983/solr/admin/cores?action=REQUESTRECOVERY&core=${FOLLOWER_CORE}"
#
#echo -e "\n=== Step 10: 监控恢复进度 ==="
#for i in {1..60}; do
#  STATE=$(curl -s "http://${LEADER_IP}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}" | \
#    jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${FOLLOWER_REPLICA}.state")
#
#  CURRENT_COUNT=$(curl -s "http://${FOLLOWER_IP}:8983/solr/${FOLLOWER_CORE}/select?q=*:*&rows=0&distrib=false" | \
#    jq -r '.response.numFound')
#
#  echo -ne "\r[$i/60] 状态: $STATE, Follower文档: $CURRENT_COUNT/$LEADER_COUNT  "
#
#  if [ "$STATE" = "active" ] && [ "$CURRENT_COUNT" = "$LEADER_COUNT" ]; then
#    echo -e "\n✅ 恢复完成！"
#    break
#  fi
#  sleep 2
#done
#
#echo -e "\n=== Step 11: 最终验证 ==="
#FINAL_FOLLOWER=$(curl -s "http://${FOLLOWER_IP}:8983/solr/${FOLLOWER_CORE}/select?q=*:*&rows=0&distrib=false" | \
#  jq -r '.response.numFound')
#echo "最终结果 - Leader: $LEADER_COUNT, Follower: $FINAL_FOLLOWER"
#
#if [ "$LEADER_COUNT" = "$FINAL_FOLLOWER" ]; then
#  echo "✅ 数据同步成功!"
#else
#  echo "❌ 数据不一致!"
#fi