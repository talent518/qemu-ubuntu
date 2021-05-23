# qemu-ubuntu
ubuntu core and desktop for qemu-kvm

### 1. first run
```sh
sudo cp qemu-if* /etc/

# reset iptables
./iptables-reset.sh

# public network share
./iptables-reset.sh
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

