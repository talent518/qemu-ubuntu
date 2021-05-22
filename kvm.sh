#!/bin/bash -l

if [ ! -f "boot.qcow2" ]; then
	qemu-img create -t qcow2 boot.qcow2 16G
fi

if [ ! -f "ubuntu-20.04.2.0-desktop-amd64.iso" ]; then
	wget -O ubuntu-20.04.2.0-desktop-amd64.iso 'http://cdimage.ubuntu.com/xubuntu/releases/20.04.2/release/xubuntu-20.04.2.0-desktop-amd64.iso'
fi

sudo kvm -smp 2 -m 1024M \
	-net nic,model=e1000e \
	-net tap,script=/etc/qemu-ifup,downscript=/etc/qemu-ifdown \
	-cdrom ubuntu-20.04.2.0-desktop-amd64.iso \
	$@ boot.qcow2

