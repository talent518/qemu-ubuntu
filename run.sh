#!/bin/bash

set -e

N=$(cat /proc/cpuinfo | grep -c ^processor)
kver=${KVER:-5.12.7}
bver=${BVER:-21.04}
platform=${PLATFORM:-amd64}
msize=${MSIZE:-1024M}

nic=e1000e

if [ "$platform" = "amd64" ]; then
	if [ $(grep -c -E '(svm|vmx)' /proc/cpuinfo) -gt 0 ]; then
		kvm=kvm
		pkg=qemu-kvm
	else
		kvm=qemu-system-$(uname -p)
		pkg=qemu-system-x86
	fi

	arch=$(uname -p)
	cross=
	image=bzImage

	append="root=/dev/sda rw console=ttyAMA0 loglevel=6 init=/bin/systemd $APPEND"
elif [ "$platform" = "armhf" ]; then
	kvm="qemu-system-arm -machine virt -cpu cortex-a8"
	pkg="qemu-system-arm gcc-arm-linux-gnueabihf"

	arch=arm
	cross=arm-linux-gnueabihf-
	image=Image.gz

	append="root=/dev/vda rw console=ttyAMA0 $APPEND"
else
	platform=arm64
	kvm="qemu-system-aarch64 -machine virt -cpu cortex-a57"
	pkg="qemu-system-aarch64 gcc-aarch64-linux-gnu"

	arch=arm64
	cross=aarch64-linux-gnu-
	image=Image.gz

	append="root=/dev/vda rw console=ttyAMA0 $APPEND"
fi

sudo dpkg -l qemu-user-static $pkg

if [ -f "bzImage-$arch" ]; then
	kernel=./bzImage-$arch
else
	kernel=linux-$kver-$arch/arch/$arch/boot/$image

	if [ ! -d linux-$kver-$arch ]; then
		if [ ! -f linux-$kver.tar.xz ]; then
			wget -O linux-$kver.tar.xz https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/linux-$kver.tar.xz
		fi
		tar -xvf linux-$kver.tar.xz
		mv linux-$kver linux-$kver-$arch
	fi
	
	if [ ! -f linux-$kver-$arch/.config ]; then
		sed 's|=m$|=y|g' linux-$kver-$arch/arch/$arch/configs/defconfig > linux-$kver-$arch/arch/arm64/configs/arm64_defconfig
		cat - >> linux-$kver-$arch/arch/arm64/configs/arm64_defconfig <<!
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_RAM_COUNT=16
CONFIG_BLK_DEV_RAM_SIZE=65536
!
		make -C linux-$kver-$arch ARCH=$arch CROSS_COMPILE=$cross arm64_defconfig
	fi

	make -C linux-$kver-$arch ARCH=$arch CROSS_COMPILE=$cross -j$N
fi

if [ ! -f "boot-$arch.img" -o ! -f "boot-$arch.ok" ]; then
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

	dd if=/dev/zero of=boot-$arch.img bs=1M count=8192
	mkfs.ext4 -L rootfs boot-$arch.img

	sudo mount boot-$arch.img boot
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

echo abao-u${bver:0:2}-$arch > /etc/hostname
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

	e2fsck -p -f boot-$arch.img
	rmdir boot

	touch boot-$arch.ok
fi

sudo $kvm -smp $N -m $msize \
	-kernel $kernel \
	-hda boot-$arch.img \
	-append "$append" \
	-net nic,model=$nic \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$@

