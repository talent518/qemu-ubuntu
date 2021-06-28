#!/bin/bash -l

set -e

N=$(nproc)

build=$PWD/build

kver=5.12.7
kfile=linux-$kver.tar.xz
kpath=linux-$kver-tiny
kbuild=$build/kernel

bver=1.32.1
bfile=busybox-$bver.tar.bz2
bpath=busybox-$bver-tiny
bbuild=$build/busybox

kvm="kvm -smp 2 -m 256"

eval $@

function quit() {
	rm -vf $1 || exit 255
	exit $2
}

# build kernel
test -d $kbuild || mkdir -p $kbuild || exit 1
test -f $kfile || wget -O $kfile https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/$kfile || quit $kfile 2
if [ ! -d $kpath ]; then
	rm -vrf linux-$kver
	tar -xvf $kfile || quit "-r linux-$kver" 3
	mv linux-$kver $kpath || exit 4
fi
test -f $kbuild/.config || make -C $kpath O=$kbuild defconfig || exit 5
test -f "$kbuild/vmlinux" || make -C $kpath O=$kbuild -j$N || exit 6

# build busybox
test -d $bbuild || mkdir -p $bbuild || exit 7
test -f $bfile || wget -O $bfile https://busybox.net/downloads/$bfile || exit 8
if [ ! -d $bpath ]; then
	rm -vrf busybox-$bver
	tar -xvf $bfile || quit "-r busybox-$bver" 9
	mv busybox-$bver $bpath || exit 10
fi
test -f $bbuild/.config || make -C $bpath O=$bbuild defconfig || exit 11
test -f "$bbuild/busybox" || make -C $bpath O=$bbuild -j$N  CONFIG_STATIC=y || exit 12

# tiny rootfs
if [ ! -f "boot-tiny.img" -o ! -f "boot-tiny.ok" ]; then
	if [ -d boot ]; then
		if [ "$(df --output=target boot|tail -n1)" = "$(realpath boot)" ]; then
			sudo umount -qv boot || exit 13
		fi
	else
		mkdir boot || exit 14
	fi

	dd if=/dev/zero of=boot-tiny.img bs=1M count=128 || exit 15
	mkfs.ext4 -L rootfs boot-tiny.img || exit 16

	sudo mount boot-tiny.img boot || exit 17

	sudo mkdir -p boot/bin boot/sbin boot/usr/bin boot/usr/sbin boot/lib/modules boot/root boot/dev boot/sys boot/proc boot/etc/init.d boot/etc/profile.d boot/etc/network/if-up.d boot/etc/network/if-pre-up.d boot/etc/network/if-down.d boot/etc/network/if-post-down.d boot/tmp boot/var/run || exit 18
	sudo cp -v $bbuild/busybox boot/bin/busybox || exit 19
	$bbuild/busybox --list-full | while read f; do
		sudo ln -sfv /bin/busybox boot/$f || exit 21
	done || exit 20

	sudo cp /etc/localtime boot/etc/ || exit 22

	# /etc/passwd
	cat - > passwd <<!
root::0:0:root:/root:/bin/sh
!
	sudo mv passwd boot/etc/ || exit 23

	# /etc/group
	cat - > group <<!
root:x:0:
!
	sudo mv group boot/etc/ || exit 23

	# /etc/hostname
	cat - > hostname <<!
tiny
!
	sudo mv hostname boot/etc/ || exit 23

	# /etc/init.d/rcS
	cat - > rcS <<!
#!/bin/sh -l

hwclock -s
hostname -F /etc/hostname
mount -a
ifdown -af
ifup -af
!
	sudo chmod +x rcS || exit 24
	sudo mv rcS boot/etc/init.d/ || exit 25

	# /etc/profile
	cat - > profile <<!
PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\\$ "
if [ -d /etc/profile.d ]; then
  for i in /etc/profile.d/*.sh; do
    if [ -r \$i ]; then
      . \$i
    fi
  done
  unset i
fi
alias l='ls -lF'
alias ll='ls -alF'
alias ls='ls --color=auto --full-time'
!
	sudo mv profile boot/etc/ || exit 26

	# /etc/fstab
	cat - > fstab <<!
proc /proc proc defaults 0 0
sys /sys sysfs defaults 0 0
!
	sudo mv fstab boot/etc/ || exit 27

	# /etc/inittab
	cat - > inittab <<!
::sysinit:/etc/init.d/rcS
::respawn:/sbin/getty 115200 ttyS0
::restart:/sbin/init
::shutdown:/bin/umount -a -r
!
	sudo mv inittab boot/etc/ || exit 28


	# /etc/interfaces
	cat - > interfaces <<!
# lo
auto lo
iface lo inet loopback
    address 127.0.0.1
    netmask 255.0.0.0

# eth0
auto eth0
iface eth0 inet dhcp
!
	sudo mv interfaces boot/etc/network/ || exit 29

	sudo sh -e -c 'cd boot/dev;mknod -m 600 console c 5 1;mknod -m 666 null c 1 3' || exit 100

	sudo make -C $kpath O=$kbuild INSTALL_MOD_PATH=$PWD/boot modules_install || exit 101
	test ${kernel_header:-0} -gt 0 && ( sudo make -C $kpath O=$kbuild INSTALL_HDR_PATH=$PWD/boot/usr headers_install || exit 102 )

	sudo chown -R root.root boot/etc || 250

	sudo umount boot || exit 251
	
	e2fsck -p -f boot-tiny.img || exit 252
	rmdir boot || exit 253

	touch boot-tiny.ok || exit 254
fi

sudo $kvm \
	-kernel "${kernel:-$kbuild/arch/x86/boot/bzImage}" \
	-append "root=/dev/sda rw console=ttyS0 loglevel=6 init=/linuxrc $append" \
	-hda boot-tiny.img \
	-net nic,model=${nic:-e1000e} \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	-nographic
	$opts
