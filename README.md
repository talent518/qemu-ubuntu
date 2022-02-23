# qemu-ubuntu
ubuntu core and desktop for qemu-kvm

### 1. first run
```sh
sudo cp qemu-if* /etc/

# reset iptables
./iptables-reset.sh

# public network share
./iptables-nat.sh
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
make -C src/linux-5.12.7 O=$PWD/out/kernel-amd64 DEBUG_CFLAGS='-gdwarf-2 -gstrict-dwarf -g' -j3
ln -sf out/kernel-amd64/arch/x86/boot/bzImage bzImage-amd64
```
### 6. kdump for crash dump

##### 6.1. .config
CONFIG_KEXEC=y
CONFIG_SYSFS=y
CONFIG_DEBUG_INFO=y
CONFIG_CRASH_DUMP=y
CONFIG_PROC_VMCORE=y

##### 6.2. build
* amd64
```sh
make -C src/linux-5.12.7 O=$PWD/out/kernel-amd64 x86_64_defconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-amd64 menuconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-amd64 DEBUG_CFLAGS='-gdwarf-2 -gstrict-dwarf -g' -j4
ln -sf out/kernel-amd64/arch/x86/boot/bzImage bzImage-amd64
```
* arm64
```sh
make -C src/linux-5.12.7 O=$PWD/out/kernel-arm64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- defconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-arm64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- menuconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-arm64 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- DEBUG_CFLAGS="-gdwarf-2 -gstrict-dwarf -g" -j4
ln -sf out/kernel-arm64/arch/arm64/boot/Image.gz bzImage-arm64
```
* armhf
```sh
make -C src/linux-5.12.7 O=$PWD/out/kernel-armhf ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- vexpress_defconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-armhf ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- menuconfig
make -C src/linux-5.12.7 O=$PWD/out/kernel-armhf ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- DEBUG_CFLAGS="-gdwarf-2 -gstrict-dwarf -g" -j4
ln -sf out/kernel-armhf/arch/arm/boot/zImage bzImage-armhf
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
* nographic
```
./tiny.sh
```
* vga mode
```
./tiny.sh vga=1
```

