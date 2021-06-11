#!/bin/bash -l

set -e

RESET="\033[0m"

FG_BLACK="\033[30m"
FG_RED="\033[31m"
FG_GREEN="\033[32m"
FG_YELLOW="\033[33m"
FG_BLUE="\033[34m"
FG_PURPLE="\033[35m"
FG_CYAN="\033[36m"
FG_GREY="\033[37m"

BG_BLACK="\033[40m"
BG_RED="\033[41m"
BG_GREEN="\033[42m"
BG_YELLOW="\033[43m"
BG_BLUE="\033[44m"
BG_PURPLE="\033[45m"
BG_CYAN="\033[46m"
BG_GREY="\033[47m"


function repeat() {
	n=$2
	while [ $n -gt 0 ]; do
		n=$(expr $n - 1)
		echo -n $1
	done
}

function line() {
	q=$(expr 50 - ${#1})
	b=$(expr $q / 2)
	e=$(expr $q - $b)
	printf "${FG_CYAN}%s${FG_PURPLE}%d${FG_CYAN}%s${RESET}\n" $(repeat \= $b) $1 $(repeat \= $e)
}

STEP=0
function step() {
	STEP=$(expr $STEP + 1)
	t=$1
	shift 1
	if [ $# -gt 0 ]; then
		p=' '
	fi
	line $STEP
	printf "${FG_RED}%s${RESET}%s\n" "$t" "$p$*"
}

function vars() {
	printf "${FG_RED}变量${RESET}\n"
	while [ $# -gt 0 ]; do
		printf "  ${FG_GREEN}$1\033[0m: ${FG_BLUE}$(eval echo "\$$1")${RESET}\n"
		shift
	done
}

ver=21.04
arch=amd64
user=abao

while [ $# -gt 0 ]; do
	case "$1" in
		"-v")
			ver=$2
			shift
			;;
		"-a")
			arch=$2
			shift
			;;
		"-u")
			user=$2
			shift
			;;
		*)
			echo "usage: $0 [-v ver] [-a arch] [-u user]" >&2;
			exit 1
			;;
	esac
	shift
done

#############################################

vars ver arch

#############################################

step "创建root目录"

if [ -d root ]; then
	b=$(df --output=target root|tail -1)
	e=$(realpath root)
	if [ "$b" = "$e" ]; then
		sudo fuser -kv root
		sudo umount root/proc root/sys root/dev
		sudo umount root
	fi
else
	mkdir root
fi

#############################################

step "创建根文件系统"

dd if=/dev/zero of=root.img bs=1M count=1024
mkfs.ext4 root.img

#############################################

step "挂载根文件系统"

sudo mount root.img root

#############################################

step "解压ubuntu"
sudo tar -xf ubuntu-base-$ver-base-$arch.tar.gz -C root/

#############################################

step "准备网络"
sudo cp -vf /etc/resolv.conf root/etc/resolv.conf

#############################################

step "创建用户"

cat - > init <<!
#!/bin/bash -l
useradd -s /bin/bash -m -G adm,sudo $user
echo "$user ALL=(ALL:ALL) ALL" >> /etc/sudoers
echo -n "root "
passwd root
echo -n "$user "
passwd $user
rm -vf \$0
!

sudo chown -R root.root init
sudo chmod +x init
sudo mv init root/

sudo mount -t proc /proc root/proc
sudo mount -t sysfs /sys root/sys
sudo mount -o bind /dev root/dev
sudo chroot root/ /init
sudo umount root/proc root/sys root/dev

#############################################

step "取消挂载并检查根文件系统"

sudo umount root
rmdir root
e2fsck -p -f root.img

#############################################

