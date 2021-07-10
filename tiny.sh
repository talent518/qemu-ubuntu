#!/bin/bash -l

####################################################
#                  vga mode                       ##
####################################################
# color | 640x800 | 800x600 | 1024x768 | 1280x1024 #
####################################################
# 256   |  0x301  |  0x303  |  0x305   |   0x307   #
# 32K   |  0x310  |  0x313  |  0x316   |   0x319   #
# 64K   |  0x311  |  0x314  |  0x317   |   0x31A   #
# 16M   |  0x312  |  0x315  |  0x318   |   0x31B   #
####################################################
#                 ./tiny.sh vga=1                  #
####################################################

set -e

N=$(nproc)

src=$PWD/src
out=$PWD/out

kver=5.12.7
kfile=linux-$kver.tar.xz
kpath=$src/linux-$kver
kout=$out/kernel-tiny

bver=1.32.1
bfile=busybox-$bver.tar.bz2
bpath=$src/busybox-$bver
bout=$out/busybox

kvm="kvm -smp 2 -m 256"
opts="-nographic"
vga=0
append=

eval $@

if [ $vga -ne 0 ]; then
	if [ "$opts" = "-nographic" ]; then
		opts=
	fi
	append="$append console=tty0 vga=0x318"
fi

function quit() {
	rm -vf $1 || exit 255
	exit $2
}

mkdir -p $src

# build kernel
test -d $kout || mkdir -p $kout || exit 1
test -f $kfile || wget -O $kfile https://cdn.kernel.org/pub/linux/kernel/v${kver:0:1}.x/$kfile || quit $kfile 2
test -d $kpath || tar -xvf $kfile -C $src || quit "-r $kpath" 3
if [ ! -f "$kout/.config" ]; then
	make -C $kpath O=$kout defconfig || exit 5
	echo "CONFIG_FB_BOOT_VESA_SUPPORT=y" >> $kout/.config
	echo "CONFIG_FB_VESA=y" >> $kout/.config
fi
test -f "$kout/vmlinux" || make -C $kpath O=$kout -j$N || exit 6

# build busybox
test -d $bout || mkdir -p $bout || exit 7
test -f $bfile || wget -O $bfile https://busybox.net/downloads/$bfile || exit 8
test -d $bpath || tar -xvf $bfile -C $src || quit "-r $bpath" 3
test -f $bout/.config || make -C $bpath O=$bout defconfig || exit 11
test -f "$bout/busybox" || make -C $bpath O=$bout -j$N CONFIG_STATIC=y || exit 12
test "$bout/index.cgi" -nt "$bpath/networking/httpd_indexcgi.c" || ${CROSS_COMPILE}gcc -static -o "$bout/index.cgi" "$bpath/networking/httpd_indexcgi.c"

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

	sudo mkdir -p boot/bin boot/sbin boot/usr/bin boot/usr/sbin boot/lib/modules boot/root/cgi-bin boot/dev boot/sys boot/proc boot/etc/init.d boot/etc/profile.d boot/etc/network/if-up.d boot/etc/network/if-pre-up.d boot/etc/network/if-down.d boot/etc/network/if-post-down.d boot/tmp boot/var/run || exit 18
	sudo cp -v $bout/busybox boot/bin/busybox || exit 19
	$bout/busybox --list-full | while read f; do
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

echo -n show hardware clock
hwclock -r

echo set host name ...
hostname -F /etc/hostname

echo mount all disk ...
mkdir -p /dev/pts
mount -a

echo config network card ...
ifdown -af
ifup -af

echo start telnet server ...
telnetd

echo start ftp server ...
mkdir -p /var/log/ftp
nohup tcpsvd -vE 0.0.0.0 21 ftpd -w /root >/var/log/ftp/access.log 2>/var/log/ftp/error.log &

echo start http server ...
httpd -r "Authentication" -h /root -vv
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
alias halt=poweroff
!
	sudo mv profile boot/etc/ || exit 26

	# /etc/fstab
	cat - > fstab <<!
proc /proc proc defaults 0 0
sys /sys sysfs defaults 0 0
devpts /dev/pts devpts defaults 0 0
!
	sudo mv fstab boot/etc/ || exit 27

	# /etc/inittab
	cat - > inittab <<!
console::sysinit:/etc/init.d/rcS
ttyS0::respawn:/sbin/getty 115200 ttyS0
tty1::respawn:/bin/login -p
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
iface eth0 inet static
    address 192.168.3.100
    netmask 255.255.255.0
    gateway 192.168.3.1
!
	sudo mv interfaces boot/etc/network/ || exit 29

	sudo sh -e -c 'cd boot/dev;mknod -m 600 console c 5 1;mknod -m 666 null c 1 3' || exit 100

	sudo make -C $kpath O=$kout INSTALL_MOD_PATH=$PWD/boot modules_install || exit 101
	test ${kernel_header:-0} -gt 0 && ( sudo make -C $kpath O=$kout INSTALL_HDR_PATH=$PWD/boot/usr headers_install || exit 102 )
	sudo cp $bout/index.cgi boot/root/cgi-bin/

	sudo chown -R root.root boot/etc || 250

	sudo umount boot || exit 251
	
	e2fsck -p -f boot-tiny.img || exit 252
	rmdir boot || exit 253

	touch boot-tiny.ok || exit 254
fi

sudo $kvm \
	-kernel "${kernel:-$kout/arch/x86/boot/bzImage}" \
	-append "root=/dev/sda rw console=ttyS0 loglevel=6 init=/linuxrc $append" \
	-hda boot-tiny.img \
	-net nic,model=${nic:-e1000e} \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$opts
