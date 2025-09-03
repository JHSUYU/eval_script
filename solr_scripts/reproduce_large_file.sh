#!/bin/bash

# 检查并安装依赖
echo "=== 检查系统依赖 ==="

# 检查Python3
if ! command -v python3 &> /dev/null; then
    echo "Python3 未安装，正在安装..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
    if [ $? -ne 0 ]; then
        echo "错误: Python3 安装失败!"
        exit 1
    fi
    echo "Python3 安装成功"
else
    echo "✓ Python3 已安装 ($(python3 --version))"
fi

# 检查jq（用于JSON解析）
if ! command -v jq &> /dev/null; then
    echo "jq 未安装，正在安装..."
    sudo apt-get install -y jq
    if [ $? -ne 0 ]; then
        echo "错误: jq 安装失败!"
        exit 1
    fi
    echo "jq 安装成功"
else
    echo "✓ jq 已安装 ($(jq --version))"
fi

# 检查curl
if ! command -v curl &> /dev/null; then
    echo "curl 未安装，正在安装..."
    sudo apt-get install -y curl
    if [ $? -ne 0 ]; then
        echo "错误: curl 安装失败!"
        exit 1
    fi
    echo "curl 安装成功"
else
    echo "✓ curl 已安装"
fi

echo "所有依赖检查完成"
echo ""

# 配置变量
USER="ZhenyuLi"
HOSTS=("ms1132.utah.cloudlab.us" "ms1101.utah.cloudlab.us")
IPS=("10.10.1.1" "10.10.1.2")
SOLR_BIN="/opt/Solr/solr/bin/solr"
COLLECTION="mycollection"

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

echo -e "\n=== Step 5: 在leader上导入大量文档 (创造差异) ==="

echo -e "\n=== Step 5: 在leader上导入大量文档 (创造差异) ==="
# 配置导入参数
#1千万
TOTAL_DOCS=10000    # 总文档数 - 10000个
DOC_SIZE_KB=10      # 每个文档约10KB
THREAD_COUNT=25     # 并发线程数

echo "将导入 $TOTAL_DOCS 个文档（每个约${DOC_SIZE_KB}KB，总计约100MB），使用 $THREAD_COUNT 个线程并发..."

# 使用Python分批生成并导入
python3 << EOF
import json
import urllib.request
import urllib.error
import threading
from queue import Queue
import time

leader_ip = "${LEADER_IP}"
collection = "${COLLECTION}"
total_docs = ${TOTAL_DOCS}
doc_size_kb = ${DOC_SIZE_KB}
thread_count = ${THREAD_COUNT}

# 生成约10KB的内容（安全地在32KB限制内）
content_repeat = 1000  # "this is content " 约16字节 * 500 = 8KB
base_content = "this is content "
medium_content = base_content * content_repeat

# 线程安全的计数器
success_lock = threading.Lock()
success_count = 0
fail_count = 0
processed_batches = 0

# 创建任务队列
task_queue = Queue()
batch_size = 50  # 每批100个文档
total_batches = (total_docs + batch_size - 1) // batch_size

# 生成所有批次任务
for batch_start in range(0, total_docs, batch_size):
    batch_end = min(batch_start + batch_size, total_docs)
    batch_num = batch_start // batch_size + 1
    task_queue.put((batch_start, batch_end, batch_num))

def worker():
    """工作线程函数"""
    global success_count, fail_count, processed_batches

    while not task_queue.empty():
        try:
            batch_start, batch_end, batch_num = task_queue.get(timeout=1)
        except:
            break

        # 生成这批文档
        docs = []
        for i in range(batch_start + 1, batch_end + 1):
            doc = {
                "id": f"doc_{i}",
                "title": f"Document {i}",
                "content": medium_content + f" unique_part_{i}",
                "timestamp": f"2024-01-{(i % 30) + 1:02d}T12:00:00Z",
                "category": f"category_{i % 100}"
            }
            docs.append(doc)

        # 发送到Solr
        try:
            url = f"http://{leader_ip}:8983/solr/{collection}/update?min_rf=1&commit=false"
            data = json.dumps(docs).encode('utf-8')
            req = urllib.request.Request(url, data=data, headers={'Content-Type': 'application/json'})

            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status == 200:
                    with success_lock:
                        success_count += len(docs)
                        processed_batches += 1
                        print(f"[线程 {threading.current_thread().name}] 批次 {batch_num}/{total_batches}: 成功导入 {len(docs)} 个文档")
                else:
                    with success_lock:
                        fail_count += len(docs)
                        print(f"[线程 {threading.current_thread().name}] 批次 {batch_num}: 失败 (HTTP {response.status})")
        except Exception as e:
            with success_lock:
                fail_count += len(docs)
                print(f"[线程 {threading.current_thread().name}] 批次 {batch_num}: 错误 - {str(e)}")

        task_queue.task_done()


# 启动线程
print(f"启动 {thread_count} 个工作线程...")
threads = []
start_time = time.time()

for i in range(thread_count):
    t = threading.Thread(target=worker, name=f"Worker-{i+1}")
    t.start()
    threads.append(t)

# 等待所有线程完成
for t in threads:
    t.join()

elapsed_time = time.time() - start_time

# 最后提交
print("\n正在执行最终提交...")
try:
    commit_url = f"http://{leader_ip}:8983/solr/{collection}/update?commit=true"
    with urllib.request.urlopen(commit_url) as response:
        print(f"最终提交完成，HTTP状态: {response.status}")
except Exception as e:
    print(f"提交失败: {str(e)}")

total_size_mb = (success_count * doc_size_kb) / 1024
print(f"\n导入总结：")
print(f"  成功: {success_count} 个文档")
print(f"  失败: {fail_count} 个文档")
print(f"  总数据量: 约 {total_size_mb:.1f} MB")
print(f"  处理时间: {elapsed_time:.2f} 秒")
print(f"  平均速度: {success_count/elapsed_time:.0f} 文档/秒")
EOF


echo -e "\n=== Step 6: 查看leader文档数 ==="

echo -e "\n=== Step 7: 查看leader文档数 ==="
LEADER_COUNT=$(curl -s "http://${LEADER_IP}:8983/solr/${LEADER_CORE}/select?q=*:*&rows=0&distrib=false" | \
  jq -r '.response.numFound')
echo "Leader文档数: $LEADER_COUNT"

echo -e "\n=== Step 8: 重启follower节点 ==="
ssh "$USER@$FOLLOWER_HOST" "$SOLR_BIN start -c -z 10.10.1.1:2181,10.10.1.2:2181,10.10.1.3:2181 -p 8983 -h ${FOLLOWER_IP} -s /opt/SolrData -m 8g"
sleep 10

echo -e "\n=== Step 9: 查看恢复前的差异 ==="
FOLLOWER_COUNT=$(curl -s "http://${FOLLOWER_IP}:8983/solr/${FOLLOWER_CORE}/select?q=*:*&rows=0&distrib=false" | \
  jq -r '.response.numFound')
echo "Leader: $LEADER_COUNT, Follower: $FOLLOWER_COUNT"
echo "差异: $((LEADER_COUNT - FOLLOWER_COUNT)) 文档"

echo -e "\n=== Step 10: Recovery命令 ==="
echo "如需触发recovery，执行以下命令："
echo "curl http://${FOLLOWER_IP}:8983/solr/admin/cores?action=REQUESTRECOVERY&core=${FOLLOWER_CORE}"

echo -e "\n=== 完成 ==="
echo "测试脚本执行完毕。"
echo "当前状态："
echo "  - Leader节点文档数: $LEADER_COUNT"
echo "  - Follower节点文档数: $FOLLOWER_COUNT"
echo "  - 数据差异: $((LEADER_COUNT - FOLLOWER_COUNT)) 文档"
echo ""
echo "后续操作："
echo "1. 使用上述recovery命令触发恢复"
echo "2. 监控恢复状态: curl http://${LEADER_IP}:8983/solr/admin/collections?action=CLUSTERSTATUS&collection=${COLLECTION}"
echo "3. 验证数据同步: curl http://${FOLLOWER_IP}:8983/solr/${FOLLOWER_CORE}/select?q=*:*&rows=0&distrib=false"