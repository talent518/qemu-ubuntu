#!/bin/bash

set -e

N=$(cat /proc/cpuinfo | grep -c ^processor)
kver=${KVER:-5.12.7}
bver=${BVER:-21.04}


if [ -f "bzImage" ]; then
	kernel=./bzImage
else
	kernel=linux-$kver/arch/$(uname -p)/boot/bzImage

	if [ ! -d linux-$kver ]; then
		test -f linux-$kver.tar.xz || wget -O linux-$kver.tar.xz https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/linux-$kver.tar.xz
		tar -xvf linux-$kver.tar.xz
	fi
	
	if [ ! -f linux-$kver/.config ]; then
		if [ "$KERNEL" = "all" ]; then
			cp /boot/config-$(uname -r) linux-$kver/.config
			sed -i 's|CONFIG_SYSTEM_TRUSTED_KEYS="debian/canonical-certs.pem"|CONFIG_SYSTEM_TRUSTED_KEYS=""|g' linux-$kver/.config
			make -C linux-$kver oldconfig
		else
			make -C linux-$kver defconfig
		fi
	fi
	
	make -C linux-$kver -j$N
fi

if [ ! -f "boot.img" -o ! -f "boot.ok" ]; then
	test -f ubuntu-base-$bver-base-amd64.tar.gz || wget -O ubuntu-base-$bver-base-amd64.tar.gz http://cdimage.ubuntu.com/ubuntu-base/releases/$bver/release/ubuntu-base-$bver-base-amd64.tar.gz

	if [ -d boot ]; then
		if [ "$(df --output=target boot|tail -n1)" = "$(realpath boot)" ]; then
			sudo umount -qv boot/proc boot/sys boot/dev/pts boot/dev boot
		fi
	else
		mkdir boot
	fi

	dd if=/dev/zero of=boot.img bs=1M count=8192
	mkfs.ext4 -L rootfs boot.img

	sudo mount boot.img boot
	sudo tar -xvf ubuntu-base-$bver-base-amd64.tar.gz -C boot/

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
set -e
test -n "$http_proxy" && export http_proxy=$http_proxy
test -n "$https_proxy" && export https_proxy=$https_proxy
apt update
apt upgrade -y --fix-missing
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

	e2fsck -p -f boot.img
	rmdir boot

	touch boot.ok
fi

sudo kvm -smp $N -m ${MSIZE:-1024M} \
	-kernel $kernel \
	-hda boot.img \
	-append "root=/dev/sda rw console=tty0 console=ttyS0 console=ttyAMR0 init=/bin/systemd loglevel=6 $APPEND" \
	-net nic,model=e1000e \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$@
