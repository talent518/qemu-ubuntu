#!/bin/bash -l

# reset the default policies in the filter table.
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

# reset the default policies in the nat table.
sudo iptables -t nat -P PREROUTING ACCEPT
sudo iptables -t nat -P POSTROUTING ACCEPT
sudo iptables -t nat -P OUTPUT ACCEPT

# reset the default policies in the mangle table.
sudo iptables -t mangle -P PREROUTING ACCEPT
sudo iptables -t mangle -P OUTPUT ACCEPT

# flush all the rules in the filter and nat tables.
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -t mangle -F

# erase all chains that's not default in filter and nat table.
sudo iptables -X
sudo iptables -t nat -X
sudo iptables -t mangle -X

