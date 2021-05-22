#!/bin/bash -l

set -e

ver=${1:-18}
opts=ubuntu-core-$ver-amd64.img
if [ $ver -ne 18 ]; then
	opts="-drive file=/usr/share/OVMF/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on"
	opts+=" -drive file=ubuntu-core-$ver-amd64.img,cache=none,format=raw,id=disk1,if=none"
	opts+=" -device virtio-blk-pci,drive=disk1,bootindex=1 -machine accel=kvm"
fi

if [ ! -f "ubuntu-core-$ver-amd64.img" ]; then
	if [ ! -f "ubuntu-core-$ver-amd64.img.xz" ]; then
		wget -O ubuntu-core-$ver-amd64.img.xz http://cdimage.ubuntu.com/ubuntu-core/$ver/stable/current/ubuntu-core-$ver-amd64.img.xz
	fi
	unxz -k ubuntu-core-$ver-amd64.img.xz
fi

sudo kvm -m 1024M -smp 2 \
	-nographic \
	-net nic,model=e1000e \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	$opts

