#!/bin/bash

# 配置变量
USER="ZhenyuLi"
HOSTS=("ms1132.utah.cloudlab.us" "ms1101.utah.cloudlab.us")
IPS=("10.10.1.1" "10.10.1.2")
COLLECTION="mycollection"

echo "=== Step 1: 创建collection (如果不存在) ==="
# 检查collection是否存在
EXISTS=$(curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=LIST" | jq -r ".collections | index(\"$COLLECTION\")")

if [ "$EXISTS" = "null" ]; then
    echo "创建新的collection..."
    curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=CREATE&name=${COLLECTION}&numShards=1&replicationFactor=2&collection.configName=myconfig"
    sleep 5
else
    echo "Collection $COLLECTION 已存在"
fi

echo -e "\n=== Step 2: 清空现有数据 ==="
curl -X POST -H 'Content-Type: application/json' \
  "http://${IPS[0]}:8983/solr/${COLLECTION}/update?commit=true" \
  --data-binary '{"delete":{"query":"*:*"}}'
echo "数据已清空"

echo -e "\n=== Step 3: 导入1000个文档 ==="
TOTAL_DOCS=1000
BATCH_SIZE=100  # 每批100个文档

for batch in $(seq 1 $((TOTAL_DOCS/BATCH_SIZE))); do
    echo "导入批次 $batch/$((TOTAL_DOCS/BATCH_SIZE))..."

    # 构建JSON数组
    docs="["
    for i in $(seq 1 $BATCH_SIZE); do
        id=$(((batch-1)*BATCH_SIZE + i))
        [ $i -gt 1 ] && docs+=","
        docs+="{\"id\":\"doc_${id}\",\"title\":\"文档${id}\",\"content\":\"这是文档${id}的内容\"}"
    done
    docs+="]"

    # 发送到Solr
    curl -s -X POST -H 'Content-Type: application/json' \
        "http://${IPS[0]}:8983/solr/${COLLECTION}/update?commit=false" \
        --data-binary "$docs" > /dev/null
done

# 最终提交
echo -e "\n=== Step 4: 提交所有更改 ==="
curl -s "http://${IPS[0]}:8983/solr/${COLLECTION}/update?commit=true" > /dev/null

echo -e "\n=== Step 5: 验证导入结果 ==="
# 查询总文档数
TOTAL_COUNT=$(curl -s "http://${IPS[0]}:8983/solr/${COLLECTION}/select?q=*:*&rows=0" | \
  jq -r '.response.numFound')
echo "总文档数: $TOTAL_COUNT"

# 检查每个节点的文档数
echo -e "\n=== Step 6: 检查各节点同步状态 ==="
CLUSTER_STATUS=$(curl -s "http://${IPS[0]}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}")

for replica in $(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas | keys[]"); do
    CORE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.core")
    NODE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.node_name")
    STATE=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.state")
    IS_LEADER=$(echo "$CLUSTER_STATUS" | jq -r ".cluster.collections.${COLLECTION}.shards.shard1.replicas.${replica}.leader // false")

    NODE_IP=$(echo "$NODE" | cut -d':' -f1)
    NODE_COUNT=$(curl -s "http://${NODE_IP}:8983/solr/${CORE}/select?q=*:*&rows=0&distrib=false" | \
        jq -r '.response.numFound')

    if [ "$IS_LEADER" = "true" ]; then
        echo "Leader节点 ($NODE_IP): $NODE_COUNT 文档 [状态: $STATE]"
    else
        echo "Follower节点 ($NODE_IP): $NODE_COUNT 文档 [状态: $STATE]"
    fi
done

echo -e "\n=== 完成 ==="
echo "成功导入 $TOTAL_COUNT 个文档到 $COLLECTION"