#!/bin/bash

# 在这里定义您的服务器列表
SERVERS=(
    "ZhenyuLi@ms1145.utah.cloudlab.us"
    "ZhenyuLi@ms1125.utah.cloudlab.us"
    "ZhenyuLi@ms1141.utah.cloudlab.us"
    "ZhenyuLi@ms1110.utah.cloudlab.us"
    "ZhenyuLi@ms1143.utah.cloudlab.us"
    "ZhenyuLi@ms1014.utah.cloudlab.us"
)

# 在每个服务器上生成SSH密钥
echo "=== 在每个服务器上生成SSH密钥 ==="
for server in "${SERVERS[@]}"; do
    echo "在 $server 上生成SSH密钥..."
    ssh "$server" '
        # 如果密钥已经存在，先备份
        if [ -f ~/.ssh/id_rsa ]; then
            mv ~/.ssh/id_rsa ~/.ssh/id_rsa.bak
            mv ~/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub.bak
        fi

        # 确保.ssh目录存在
        mkdir -p ~/.ssh

        # 生成密钥
        ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa

        # 添加到authorized_keys
        cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

        # 设置权限
        chmod 700 ~/.ssh
        chmod 600 ~/.ssh/authorized_keys

        echo "SSH密钥已在$(hostname)上设置完成"
    '
done

# 收集所有服务器的公钥
echo "=== 收集所有服务器的公钥 ==="
mkdir -p ./temp_keys
for server in "${SERVERS[@]}"; do
    echo "从 $server 获取公钥..."
    ssh "$server" 'cat ~/.ssh/id_rsa.pub' > "./temp_keys/$(echo $server | tr '@.' '_').pub"
done

# 将所有公钥分发到所有服务器
echo "=== 分发所有公钥到所有服务器 ==="
for server in "${SERVERS[@]}"; do
    echo "将所有公钥分发到 $server..."
    # 复制所有收集到的公钥到目标服务器
    cat ./temp_keys/*.pub | ssh "$server" 'cat >> ~/.ssh/authorized_keys'
    # 确保没有重复的条目
    ssh "$server" 'sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
    echo "公钥已成功分发到 $server"
done

# 清理临时文件
rm -rf ./temp_keys

echo "=== 测试SSH连接 ==="
for source in "${SERVERS[@]}"; do
    for target in "${SERVERS[@]}"; do
        if [ "$source" != "$target" ]; then
            echo "测试从 $source 到 $target 的SSH连接..."
            ssh "$source" "ssh -o StrictHostKeyChecking=no -o BatchMode=yes $target 'echo SSH 连接成功'"
        fi
    done
done

echo "=== 所有服务器之间的SSH无密码访问设置完成 ==="