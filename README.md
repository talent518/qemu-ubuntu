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
ver value is 16,18,20. default is 18
```sh
./kvm2.sh ver
```
### 3. ubuntu-desktop
```sh
./kvm.sh
```
### 4. ubuntu-base
* amd64
```sh
./run.sh -nographic
```
* arm64: aarch64
```sh
BVER=20.04.2 PLATFORM=arm64 ./run.sh -nographic
```
* armhf
```sh
PLATFORM=armhf ./run.sh -nographic
```
### 5. notes
CONFIG_DEBUG_INFO=y in linux-$kver/.config for crash dump
##### Error message
Dwarf Error: wrong version in compilation unit header<br/>
crash: vmlinux: no debugging data available
##### Solution
```sh
make -C linux-$kver -j3 DEBUG_CFLAGS='-gdwarf-2 -gstrict-dwarf -g'
ln -sf linux-$kver/arch/$(uname -p)/boot/bzImage .
```
### 6. kdump for crash dump

##### 6.1. .config
CONFIG_KEXEC=y
CONFIG_SYSFS=y
CONFIG_DEBUG_INFO=y
CONFIG_CRASH_DUMP=y
CONFIG_PROC_VMCORE=y

##### 6.2. build
```sh
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DEBUG_CFLAGS="-gdwarf-2 -gstrict-dwarf -g" -j4
```
##### 6.3. login to system
```sh
sudo kexec -p --command-line="root=/dev/sda rw console=tty0 console=ttyS0 console=ttyAMR0 loglevel=6 nr_cpus=2 nr_cpus=1" $PWD/bzImage
sudo sh -c 'echo c > /proc/sysrq-trigger'
```
##### 6.4. login to panic mode
```sh
sudo cp /proc/vmcore vmcore.df 
reboot
```
##### 6.5. login to system
```sh
# build crash 7.3.0 for solution error: cannot determine VA_BITS_ACTUAL
crash vmlinux vmcore.df 
```
### 7. tiny linux
```
./tiny.sh
```

