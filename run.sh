#!/bin/bash

set -e

N=$(cat /proc/cpuinfo | grep -c ^processor)
kver=${KVER:-5.12.7}
bver=${BVER:-21.04}
platform=${PLATFORM:-amd64}
msize=${MSIZE:-1024M}

if [ $(grep -c -E '(svm|vmx)' /proc/cpuinfo) -gt 0 ]; then
	kvm=kvm
	pkg=qemu-kvm
elif [ "$platform" = "amd64" ]; then
	kvm=qemu-system-$(uname -p)
	pkg=qemu-system-x86
else
	kvm=qemu-system-aarch64
	pkg="qemu-system-aarch64 gcc-aarch64-linux-gnu"
fi

sudo dpkg -l qemu-user-static $pkg

if [ "$platform" = "amd64" ]; then
	arch=$(uname -p)
	cross=
else
	arch=arm64
	cross=aarch64-linux-gnu-
fi

if [ -f "bzImage-$arch" ]; then
	kernel=./bzImage-$arch
else
	kernel=linux-$kver/arch/$arch/boot/bzImage

	if [ ! -d linux-$kver ]; then
		if [ ! -f linux-$kver.tar.xz ]; then
			wget -O linux-$kver.tar.xz https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/linux-$kver.tar.xz
		fi
		tar -xvf linux-$kver.tar.xz
	fi
	
	if [ ! -f linux-$kver/.config ]; then
		make -C linux-$kver ARCH=$arch CROSS_COMPILE=$cross defconfig
	fi

	make -C linux-$kver ARCH=$arch CROSS_COMPILE=$cross -j$N
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

	#pushd linux-$kver > /dev/null
	#find . -name '*.ko' | while read f; do
	#	p=../boot/lib/modules/$kver/${f:2}
	#	sudo mkdir -vp $(dirname $p)
	#	sudo cp -v $f $p
	#done
	#popd > /dev/null

	# mount: proc sys dev
	sudo mount -t proc /proc boot/proc
	sudo mount -t sysfs /sys boot/sys
	sudo mount -o bind /dev boot/dev
	sudo mount -o bind /dev/pts boot/dev/pts

	cat - > init <<!
#!/bin/bash

set -e -x
test -n "$http_proxy" && export http_proxy=$http_proxy
test -n "$https_proxy" && export https_proxy=$https_proxy
apt update
if [ "$arch" = "amd64" ]; then
	apt upgrade -y --fix-missing
fi
apt install -y sudo language-pack-en-base ssh net-tools ethtool ifupdown iputils-ping htop vim kmod network-manager bind9-dnsutils sysstat make g++ gcc --fix-missing
hostname abao-u${bver:0:2}
useradd -m -s /bin/bash -G adm,sudo abao
passwd abao
echo "abao ALL=(ALL:ALL) ALL" >> /dev/sudoers
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
	-append "root=/dev/sda rw console=tty0 console=ttyS0 console=ttyAMR0 init=/bin/systemd loglevel=6 $APPEND" \
	-net nic,model=e1000e \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$@

