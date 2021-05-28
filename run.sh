#!/bin/bash

set -e

N=$(cat /proc/cpuinfo | grep -c ^processor)
kver=5.12.7

test -f linux-$kver.tar.xz || wget -O linux-$kver.tar.xz https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$kver.tar.xz
test -f ubuntu-base-21.04-base-amd64.tar.gz || wget -O ubuntu-base-21.04-base-amd64.tar.gz http://cdimage.ubuntu.com/ubuntu-base/releases/21.04/release/ubuntu-base-21.04-base-amd64.tar.gz

if [ ! -d linux-$kver ]; then
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

if [ ! -f "boot.img" -o ! -f "boot.ok" ]; then
	dd if=/dev/zero of=boot.img bs=1M count=8192
	mkfs.ext4 boot.img

	if [ -d boot ]; then
		if [ "$(df --output=target boot|tail -n1)" = "$(realpath boot)" ]; then
			sudo umount -qv boot/proc boot/sys boot/dev boot/dev/pts boot
		fi
	else
		mkdir boot
	fi

	sudo mount boot.img boot
	tar -xvf ubuntu-base-21.04-base-amd64.tar.gz -C boot/

	# mount: proc sys dev
	sudo mount -t proc /proc boot/proc
	sudo mount -t sysfs /sys boot/sys
	sudo mount -o bind /dev boot/dev
	sudo mount -o bind /dev/pts boot/dev/pts

	cat - > boot/init <<!
useradd -G adm,sudo abao
passwd abao
echo "abao ALL=(ALL:ALL) ALL" >> /dev/sudoers
rm -vf /init
!
	chmod +x boot/init
	sudo chroot boot /init

	# umount: proc sys dev
	sudo umount boot/proc
	sudo umount boot/sys
	sudo umount boot/dev
	sudo umount boot/dev/pts

	sudo umount boot

	e2fsck -p -f boot.img
	rmdir boot

	touch boot.ok
fi

qemu-system-x86_64 -smp 4 -m 1024M -kernel linux-$kver/arch/$(uname -p)/boot/bzImage -hda boot.img -append "root=/dev/sda console=tty0 console=ttyS0 console=ttyAMR0 init=/sbin/init loglevel=6" $@
