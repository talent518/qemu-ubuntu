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
### 4. ubuntu-base
```sh
./run.sh
```
### 5. notes
CONFIG_DEBUG_INFO=y in linux-$kver/.config for crash dump
Dwarf Error: wrong version in compilation unit header
crash: vmlinux: no debugging data available
```sh
make -C linux-$kver -j3 DEBUG_CFLAGS='-gdwarf-2 -gstrict-dwarf'
ln -sf linux-$kver/arch/$(uname -p)/boot/bzImage .
```

