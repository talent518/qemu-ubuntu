#!/bin/bash -l

set -e

ver=${1:-18}
if [ $ver -nq 18 ]; then
	ver=20
fi

if [ ! -f "ubuntu-core-$ver-amd64.img" ]; then
	if [ ! -f "ubuntu-core-$ver-amd64.img.xz" ]; then
		wget -O ubuntu-core-$ver-amd64.img.xz http://cdimage.ubuntu.com/ubuntu-core/$ver/stable/current/ubuntu-core-$ver-amd64.img.xz
	fi
	unxz -k ubuntu-core-$ver-amd64.img.xz
fi

sudo kvm -m 1024M -smp 2 \
	-net nic,model=e1000e \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	ubuntu-core-$ver-amd64.img

