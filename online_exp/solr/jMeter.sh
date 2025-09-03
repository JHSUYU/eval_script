#!/bin/bash

# 配置参数 - 根据你的环境
SOLR_HOSTS=("10.10.1.1" "10.10.1.2")  # 使用IP地址更直接
SOLR_PORT="8983"
COLLECTION="mycollection"

# 测试参数
THREADS=${1:-100}      # 默认100线程，可通过参数覆盖
DURATION=${2:-300}     # 默认300秒
RAMPUP=${3:-30}        # 默认30秒ramp-up

# 选择一个节点进行测试（可以是任一节点，或者使用负载均衡器）
# 这里默认使用第一个节点，你也可以轮流测试两个节点
SOLR_HOST=${SOLR_HOSTS[0]}

echo "================================"
echo "Solr Throughput Test Configuration"
echo "================================"
echo "Host: $SOLR_HOST:$SOLR_PORT"
echo "Collection: $COLLECTION"
echo "Threads: $THREADS"
echo "Duration: $DURATION seconds"
echo "Ramp-up: $RAMPUP seconds"
echo "================================"

# 创建JMX文件（如果不存在）
if [ ! -f "solr_test.jmx" ]; then
    echo "Creating JMX file..."
    cat > solr_test.jmx << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0">
  <hashTree>
    <TestPlan testname="Solr Test Plan" enabled="true">
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
        <collectionProp name="Arguments.arguments"/>
      </elementProp>
    </TestPlan>
    <hashTree>
      <ThreadGroup testname="Thread Group" enabled="true">
        <stringProp name="ThreadGroup.num_threads">${__P(threads,100)}</stringProp>
        <stringProp name="ThreadGroup.ramp_time">${__P(rampup,10)}</stringProp>
        <boolProp name="ThreadGroup.scheduler">true</boolProp>
        <stringProp name="ThreadGroup.duration">${__P(duration,60)}</stringProp>
        <stringProp name="ThreadGroup.delay">0</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <intProp name="LoopController.loops">-1</intProp>
        </elementProp>
      </ThreadGroup>
      <hashTree>
        <HTTPSamplerProxy testname="Solr Query" enabled="true">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments">
              <elementProp name="q" elementType="HTTPArgument">
                <stringProp name="Argument.value">${__P(query,*:*)}</stringProp>
                <stringProp name="Argument.name">q</stringProp>
              </elementProp>
              <elementProp name="rows" elementType="HTTPArgument">
                <stringProp name="Argument.value">${__P(rows,10)}</stringProp>
                <stringProp name="Argument.name">rows</stringProp>
              </elementProp>
            </collectionProp>
          </elementProp>
          <stringProp name="HTTPSampler.domain">${__P(host,localhost)}</stringProp>
          <stringProp name="HTTPSampler.port">${__P(port,8983)}</stringProp>
          <stringProp name="HTTPSampler.protocol">http</stringProp>
          <stringProp name="HTTPSampler.path">/solr/${__P(collection,test)}/select</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
        </HTTPSamplerProxy>
        <hashTree/>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>
EOF
fi

# 运行测试
echo "Starting test..."
jmeter -n -t solr_test.jmx \
  -Jhost=$SOLR_HOST \
  -Jport=$SOLR_PORT \
  -Jcollection=$COLLECTION \
  -Jthreads=$THREADS \
  -Jduration=$DURATION \
  -Jrampup=$RAMPUP \
  -l results_$(date +%Y%m%d_%H%M%S).jtl \
  -j jmeter.log

# 分析最新的结果文件
LATEST_RESULT=$(ls -t results_*.jtl | head -1)

echo -e "\n================================"
echo "Test Results Analysis"
echo "================================"

# 计算吞吐量和响应时间
tail -n +2 "$LATEST_RESULT" | awk -F',' '
BEGIN {
    min_time = 999999999
    max_time = 0
    sum_response = 0
    count = 0
    errors = 0
}
{
    # 时间戳（毫秒）
    if ($1 < min_time) min_time = $1
    if ($1 > max_time) max_time = $1

    # 响应时间
    sum_response += $2
    count++

    # 错误统计
    if ($8 == "false") errors++
}
END {
    duration = (max_time - min_time) / 1000.0
    throughput = count / duration
    avg_response = sum_response / count
    error_rate = (errors * 100.0) / count

    printf "Total Requests: %d\n", count
    printf "Test Duration: %.2f seconds\n", duration
    printf "Throughput: %.2f requests/sec\n", throughput
    printf "Average Response Time: %.2f ms\n", avg_response
    printf "Error Count: %d\n", errors
    printf "Error Rate: %.2f%%\n", error_rate
}'

# 计算百分位数
echo -e "\nResponse Time Percentiles:"
tail -n +2 "$LATEST_RESULT" | cut -d',' -f2 | sort -n | awk '
{
    data[NR] = $1
}
END {
    p50 = int(NR * 0.50)
    p90 = int(NR * 0.90)
    p95 = int(NR * 0.95)
    p99 = int(NR * 0.99)

    printf "  50th percentile: %.2f ms\n", data[p50]
    printf "  90th percentile: %.2f ms\n", data[p90]
    printf "  95th percentile: %.2f ms\n", data[p95]
    printf "  99th percentile: %.2f ms\n", data[p99]
}'

echo "================================"
echo "Results saved to: $LATEST_RESULT"