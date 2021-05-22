# qemu-ubuntu
ubuntu core and desktop for qemu-kvm

### 1. first run
```sh
sudo cp qemu-if* /etc/

# enp2s0 is public network interface, br0 is bridge
sudo iptables -t nat -P POSTROUTING DROP
sudo iptables -t filter -A FORWARD -i enp2s0 -o br0 -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -t filter -A FORWARD -i br0 -o enp2s0 -j ACCEPT
sudo iptables -t filter -P FORWARD DROP
#sudo iptables -t nat -P POSTROUTING DROP
sudo iptables -t nat -A POSTROUTING -o br0 -j MASQUERADE
```
### 2. ubuntu-core
```sh
# ver value is 16,18,20. default is 18
./kvm2.sh ver
```
### 3. ubuntu-desktop
```sh
./kvm.sh
```

