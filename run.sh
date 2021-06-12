#!/bin/bash

set -e

N=$(cat /proc/cpuinfo | grep -c ^processor)
kver=${KVER:-5.12.7}
bver=${BVER:-21.04}
platform=${PLATFORM:-amd64}
msize=${MSIZE:-1024M}

nic=e1000e
kconfig=defconfig

if [ "$platform" = "amd64" ]; then
	if [ $(grep -c -E '(svm|vmx)' /proc/cpuinfo) -gt 0 ]; then
		kvm="kvm -smp $N -m $msize"
		pkg=qemu-kvm
	else
		kvm="qemu-system-x86_64 -smp $N -m $msize"
		pkg=qemu-system-x86
	fi

	arch=x86
	cross=
	image=bzImage
	kconfig=x86_64_defconfig

	append="root=/dev/sda rw console=ttyS0 loglevel=6 init=/bin/systemd $APPEND"
	rootfs="-hda boot-$platform.img"
elif [ "$platform" = "armhf" ]; then
	dtb=linux-$kver-armhf/arch/arm/boot/dts/vexpress-v2p-ca9.dtb

	if [ -f "bootloader-$platform.dtb" ]; then
		dtb=bootloader-$platform.dtb
	fi

	kvm="qemu-system-arm -machine vexpress-a9 -smp $N -m $msize -dtb $dtb"
	pkg="qemu-system-arm gcc-arm-linux-gnueabihf"

	arch=arm
	kconfig=vexpress_defconfig
	cross=arm-linux-gnueabihf-
	image=zImage

	nic=lan9118
	append="root=/dev/mmcblk0 rw console=ttyAMA0 loglevel=6 init=/bin/systemd $APPEND"
	rootfs="-sd boot-$platform.img"
else
	platform=arm64
	kvm="qemu-system-aarch64 -machine virt -cpu cortex-a57 -smp $N -m $msize"
	pkg="qemu-system-aarch64 gcc-aarch64-linux-gnu"

	arch=arm64
	cross=aarch64-linux-gnu-
	image=Image.gz

	append="root=/dev/vda rw console=ttyAMA0 loglevel=6 init=/bin/systemd $APPEND"
	rootfs="-hda boot-$platform.img"
fi

sudo dpkg -l qemu-user-static $pkg

if [ -f "bzImage-$platform" ]; then
	kernel=./bzImage-$platform
else
	kernel=linux-$kver-$platform/arch/$arch/boot/$image

	if [ ! -d linux-$kver-$platform ]; then
		if [ ! -f linux-$kver.tar.xz ]; then
			wget -O linux-$kver.tar.xz https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/linux-$kver.tar.xz
		fi
		tar -xvf linux-$kver.tar.xz
		mv linux-$kver linux-$kver-$platform
	fi
	
	if [ ! -f linux-$kver-$platform/.config ]; then
		sed 's|=m$|=y|g' linux-$kver-$platform/arch/$arch/configs/$kconfig > linux-$kver-$platform/arch/$arch/configs/qemu_defconfig
		cat - >> linux-$kver-$platform/arch/$arch/configs/qemu_defconfig <<!
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_COUNT=16
CONFIG_BLK_DEV_RAM_SIZE=65536
!
		make -C linux-$kver-$platform ARCH=$arch CROSS_COMPILE=$cross qemu_defconfig
	fi

	make -C linux-$kver-$platform ARCH=$arch CROSS_COMPILE=$cross -j$N
fi

if [ ! -f "boot-$platform.img" -o ! -f "boot-$platform.ok" ]; then
	if [ ! -f ubuntu-base-$bver-base-$platform.tar.gz ]; then
		wget -O ubuntu-base-$bver-base-$platform.tar.gz http://cdimage.ubuntu.com/ubuntu-base/releases/$bver/release/ubuntu-base-$bver-base-$platform.tar.gz
	fi

	if [ -d boot ]; then
		if [ "$(df --output=target boot|tail -n1)" = "$(realpath boot)" ]; then
			sudo umount -qv boot/proc boot/sys boot/dev/pts boot/dev boot
		fi
	else
		mkdir boot
	fi

	dd if=/dev/zero of=boot-$platform.img bs=1M count=2048
	mkfs.ext4 -L rootfs boot-$platform.img

	sudo mount boot-$platform.img boot
	sudo tar -xvf ubuntu-base-$bver-base-$platform.tar.gz -C boot/

	# mount: proc sys dev
	sudo mount -t proc /proc boot/proc
	sudo mount -t sysfs /sys boot/sys
	sudo mount -o bind /dev boot/dev
	sudo mount -o bind /dev/pts boot/dev/pts

	cat - > init <<!
#!/bin/bash

set -e

test -n "$http_proxy" && export http_proxy=$http_proxy
test -n "$https_proxy" && export https_proxy=$https_proxy

apt update

if [ "$platform" = "amd64" ]; then
	apt upgrade -y --fix-missing
	apt install -y sudo language-pack-en-base ssh net-tools ethtool ifupdown iputils-ping htop vim kmod network-manager bind9-dnsutils sysstat make g++ gcc --fix-missing
else
	apt install -y sudo language-pack-en-base ssh net-tools ethtool ifupdown iputils-ping htop vim kmod network-manager bind9-dnsutils sysstat make g++ gcc --fix-missing --no-install-recommends
fi

echo abao-u${bver:0:2}-$platform > /etc/hostname
echo "abao ALL=(ALL:ALL) ALL" >> /dev/sudoers

useradd -m -s /bin/bash -G adm,sudo abao
passwd abao
rm -vf /init
!

	sudo mv init boot/
	sudo chmod +x boot/init

	sudo chroot boot /init

	# umount: proc sys dev
	sudo umount boot/proc
	sudo umount boot/sys
	sudo umount boot/dev/pts
	sudo umount boot/dev

	sudo umount boot

	e2fsck -p -f boot-$platform.img
	rmdir boot

	touch boot-$platform.ok
fi

sudo $kvm \
	-kernel $kernel \
	-append "$append" \
	$rootfs \
	-net nic,model=$nic \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$@

