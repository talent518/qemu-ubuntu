#!/bin/bash -l

iface=${1:-enp2s0}
src=${2:-192.168.3.0/24}

# enp2s0 is public network interface, br0 is bridge
sudo iptables -t nat -A POSTROUTING -s $src -j MASQUERADE
sudo iptables -t filter -A FORWARD -i $iface -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t filter -A FORWARD -i br0 -o $iface -j ACCEPT
sudo iptables -t filter -P FORWARD DROP
#sudo iptables -t nat -P POSTROUTING DROP

