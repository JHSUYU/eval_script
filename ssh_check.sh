#!/bin/bash

# 检查本地是否安装了expect
if ! command -v expect &> /dev/null; then
    echo "本地未安装expect工具，正在安装..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y expect
    elif command -v yum &> /dev/null; then
        sudo yum install -y expect
    else
        echo "错误: 无法自动安装expect，请手动安装"
        exit 1
    fi
fi

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 <n>"
    echo "  n: 节点数量（将遍历node0到node(n-1)的所有配对）"
    exit 1
fi

n=$1

# 验证n是否为正整数
if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -le 0 ]; then
    echo "错误: n必须是正整数"
    exit 1
fi

echo "开始遍历所有节点对 (node0 到 node$((n-1)))"
echo "总共将执行 $((n*n)) 次SSH连接"
echo "将自动回答yes接受所有SSH主机密钥"
echo "========================================"

success_count=0
fail_count=0
nodes_with_expect=()
nodes_without_expect=()

# 创建expect脚本函数
ssh_auto_yes() {
    local source=$1
    local target=$2

    expect -c "
        set timeout 10
        spawn ssh $source \"ssh $target 'hostname'\"
        expect {
            \"yes/no\" {
                send \"yes\r\"
                exp_continue
            }
            \"fingerprint\" {
                send \"yes\r\"
                exp_continue
            }
            \"password:\" {
                send_user \"需要密码，跳过\n\"
                exit 1
            }
            eof {
                exit 0
            }
            timeout {
                send_user \"连接超时\n\"
                exit 1
            }
        }
    " 2>/dev/null

    return $?
}

# 检查并安装expect的函数
check_and_install_expect() {
    local node=$1

    echo "  检查 $node 上是否安装了expect..."

    # 检查节点上是否有expect
    ssh_output=$(ssh -o StrictHostKeyChecking=no $node "command -v expect" 2>/dev/null)

    if [ -z "$ssh_output" ]; then
        echo "  $node 上未安装expect，正在安装..."

        # 尝试安装expect
        ssh -o StrictHostKeyChecking=no $node "
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y expect
            elif command -v yum &> /dev/null; then
                sudo yum install -y expect
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y expect
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y expect
            else
                echo '无法确定包管理器'
                exit 1
            fi
        " 2>/dev/null

        # 再次检查是否安装成功
        ssh_output=$(ssh -o StrictHostKeyChecking=no $node "command -v expect" 2>/dev/null)
        if [ -n "$ssh_output" ]; then
            echo "  ✓ 成功在 $node 上安装了expect"
            nodes_with_expect+=($node)
        else
            echo "  ✗ 无法在 $node 上安装expect"
            nodes_without_expect+=($node)
        fi
    else
        echo "  ✓ $node 上已安装expect"
        nodes_with_expect+=($node)
    fi
}

# 首先检查所有节点的expect安装情况
echo "步骤1: 检查并安装expect工具"
echo "----------------------------------------"
for ((i=0; i<n; i++)); do
    node="node$i"

    # 首先测试是否能连接到节点
    ssh -o StrictHostKeyChecking=no $node "hostname" &>/dev/null
    if [ $? -eq 0 ]; then
        check_and_install_expect $node
    else
        echo "  ✗ 无法连接到 $node"
    fi
done

echo ""
echo "步骤2: 测试所有节点对之间的连接"
echo "========================================"

# 遍历所有节点对 (i -> j)
for ((i=0; i<n; i++)); do
    for ((j=0; j<n; j++)); do
        source_node="node$i"
        target_node="node$j"

        echo "测试连接: $source_node -> $target_node"

        ssh_auto_yes $source_node $target_node

        if [ $? -eq 0 ]; then
            echo "  ✓ $source_node -> $target_node 成功"
            ((success_count++))

            # 连接成功后，检查目标节点是否有expect（如果还没检查过）
            if [[ ! " ${nodes_with_expect[@]} " =~ " ${target_node} " ]] && \
               [[ ! " ${nodes_without_expect[@]} " =~ " ${target_node} " ]]; then
                check_and_install_expect $target_node
            fi
        else
            echo "  ✗ $source_node -> $target_node 失败"
            ((fail_count++))
        fi
    done
    echo "----------------------------------------"
done

echo "========================================"
echo "测试完成"
echo "成功: $success_count 个连接"
echo "失败: $fail_count 个连接"
echo "总计: $((n*n)) 个连接"
echo ""
echo "Expect工具安装情况:"
echo "已安装expect的节点: ${#nodes_with_expect[@]} 个"
if [ ${#nodes_with_expect[@]} -gt 0 ]; then
    echo "  ${nodes_with_expect[@]}"
fi
echo "未安装expect的节点: ${#nodes_without_expect[@]} 个"
if [ ${#nodes_without_expect[@]} -gt 0 ]; then
    echo "  ${nodes_without_expect[@]}"
fi