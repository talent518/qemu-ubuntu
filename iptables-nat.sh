#!/bin/bash -l

# enp2s0 is public network interface, br0 is bridge
sudo iptables -t nat -A POSTROUTING -o enp2s0 -j MASQUERADE
sudo iptables -t filter -A FORWARD -i enp2s0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t filter -A FORWARD -i br0 -o enp2s0 -j ACCEPT
sudo iptables -t filter -P FORWARD DROP
#sudo iptables -t nat -P POSTROUTING DROP

