#!/bin/bash
# rootful Lepton 的 bridge/NAT/DNS/ADB 规则；可重复执行。
set -euo pipefail

LEPTON_HOME=${LEPTON_HOME:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)}
UPSTREAM_IFACE=${UPSTREAM_IFACE:-wlan0}
if test -z "${UPSTREAM_DNS:-}" && command -v resolvectl >/dev/null; then
    UPSTREAM_DNS=$(resolvectl dns "$UPSTREAM_IFACE" 2>/dev/null \
        | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {print $i; exit}}')
fi
UPSTREAM_DNS=${UPSTREAM_DNS:-1.1.1.1}
RESET_NETWORK=${RESET_NETWORK:-0}
N="--network-config-dir=${LEPTON_HOME}/containers-networks"

for module in veth xt_MASQUERADE nft_masq nft_chain_nat nf_conntrack; do
    modprobe "$module" 2>/dev/null || true
done
sysctl -w net.ipv4.ip_forward=1 >/dev/null
if ((RESET_NETWORK)); then
    if test -n "$(podman ps --filter network=lnet -q)"; then
        echo "lnet 上仍有运行中的容器，不能重建网络" >&2
        exit 1
    fi
    podman $N network rm lnet >/dev/null 2>&1 || true
    ip link delete podman1 2>/dev/null || true
fi
if ! podman $N network inspect lnet >/dev/null 2>&1; then
    NETAVARK_FW=none podman $N network create \
        --subnet=10.0.4.0/24 --gateway=10.0.4.1 lnet >/dev/null
fi

nft add table ip nat-lepton
nft add chain ip nat-lepton POSTROUTING \
    '{ type nat hook postrouting priority 100; }' 2>/dev/null || true
nft add chain ip nat-lepton PREROUTING \
    '{ type nat hook prerouting priority -100; }' 2>/dev/null || true
nft flush chain ip nat-lepton POSTROUTING
nft flush chain ip nat-lepton PREROUTING
nft add rule ip nat-lepton POSTROUTING \
    ip saddr 10.0.4.0/24 oifname "$UPSTREAM_IFACE" masquerade
nft add rule ip nat-lepton PREROUTING \
    iifname "$UPSTREAM_IFACE" tcp dport 5555 dnat to 10.0.4.2:5555
# Android 固定使用网桥 DNS；宿主网络变化时只需刷新上游地址。
nft add rule ip nat-lepton PREROUTING \
    ip daddr 10.0.4.1 udp dport 53 dnat to "$UPSTREAM_DNS:53"
nft add rule ip nat-lepton PREROUTING \
    ip daddr 10.0.4.1 tcp dport 53 dnat to "$UPSTREAM_DNS:53"

# netavark 重建容器后，宿主 veth 可能仍未加入 bridge，导致 podman1
# NO-CARRIER、Android 默认路由存在但网关不可达。按容器 iflink 找宿主 peer，
# 幂等接回；容器尚未启动时不做任何接口操作。
if podman $N inspect lepton-dev >/dev/null 2>&1 && [[ -d /sys/class/net/podman1 ]]; then
    IFLINK=$(podman $N exec lepton-dev cat /sys/class/net/eth0/iflink 2>/dev/null || true)
    if [[ "${IFLINK}" =~ ^[0-9]+$ ]]; then
        HOST_VETH=$(ip -o link show | awk -v idx="${IFLINK}:" 'index($0, idx) == 1 {print $2; exit}')
        HOST_VETH=${HOST_VETH%%@*}
        if [[ -n "${HOST_VETH}" ]]; then
            ip link set "${HOST_VETH}" master podman1
            ip link set podman1 up
        fi
    fi
fi

echo "lepton network ready (10.0.4.0/24, uplink=$UPSTREAM_IFACE, dns=$UPSTREAM_DNS)"
