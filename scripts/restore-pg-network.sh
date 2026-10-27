# 修改防火墙权限，增加了规则
#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    # exec sudo -n bash "$0"
    exec sudo -n bash "$0" "$@"
fi

# network='pg-network'
network="${1:-pipeline_default}"
dns='168.63.129.16'

# 读取当前网桥名称和子网，避免写死旧编号。
network_id=$(docker network inspect "$network" --format '{{.Id}}')
bridge=$(docker network inspect "$network" \
    --format '{{index .Options "com.docker.network.bridge.name"}}')

if [ -z "$bridge" ]; then
    bridge="br-${network_id:0:12}"
fi

subnet=$(docker network inspect "$network" \
    --format '{{(index .IPAM.Config 0).Subnet}}')

uplink=$(ip -4 route show default | awk '
    {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}
')

test -n "$subnet"
test -n "$uplink"
ip link show dev "$bridge" >/dev/null
# 已有的规则跳过，不重复添加。
allow() {
    if ! iptables-legacy -w -C FORWARD "$@" 2>/dev/null; then
        iptables-legacy -w -I FORWARD 1 "$@"
    fi
}

# 数据库请求和回复。
# 允许同一网桥内访问 TCP 5432
allow -i "$bridge" -o "$bridge" \
    -s "$subnet" -d "$subnet" \
    -m conntrack --ctstate ESTABLISHED,RELATED \
    -j ACCEPT
    # -p tcp --dport 5432 -j ACCEPT

# 允许同一网桥内已建立连接的返回流量
allow -i "$bridge" -o "$bridge" \
    -s "$subnet" -d "$subnet" \
    -p tcp --dport 5432 \
    -j ACCEPT
    # -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DNS 请求和回复。
# 向指定 DNS 查询地址
allow -i "$bridge" -o "$uplink" \
    -s "$subnet" -d "$dns" \
    -p udp --dport 53 -j ACCEPT

# 支持另一种 DNS 查询方式
allow -i "$bridge" -o "$uplink" \
    -s "$subnet" -d "$dns" \
    -p tcp --dport 53 -j ACCEPT

# 允许该 DNS 返回结果
allow -i "$uplink" -o "$bridge" \
    -s "$dns" -d "$subnet" \
    -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# HTTPS 请求和回复。
# 允许通过外网出口访问 TCP 443
allow -i "$bridge" -o "$uplink" \
    -s "$subnet" -p tcp --dport 443 \
    -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT

# 允许 HTTPS 服务器返回数据
allow -i "$uplink" -o "$bridge" \
    -d "$subnet" -p tcp --sport 443 \
    -m conntrack --ctstate ESTABLISHED -j ACCEPT

echo "PostgreSQL 网络放行规则已检查并配置"




