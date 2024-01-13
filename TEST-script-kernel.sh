#!/bin/bash
## -= \nEzKernel install script =-
## Tested for Debian EzKernel Xanmod config only. May need modification for other kernels
## Author: thorbits, under GPL v2.+ {url}
## ------------------------------------------------------------------------------------------

## Questions that you really, really need to see (or else). ##
export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

export DEBIAN_PRIORITY=critical

greeting[0]="Hola"
greeting[1]="Hello"
greeting[2]="Welcome"
greeting[3]="Hi there"
greeting[4]="Howdy"

size=${#greeting[@]}
index=$(($RANDOM % $size))

echo ${greeting[$index]} $USER

echo -e '\nWelcome to Debian EzKernel\n\nPreparing files...\n'

echo -e "deb http://ftp.ca.debian.org/debian sid main contrib\ndeb-src http://ftp.ca.debian.org/debian sid main contrib\n\ndeb http://security.debian.org/debian-security bookworm-security main contrib\ndeb-src http://security.debian.org/debian-security bookworm-security main contrib" > /etc/apt/sources.list
apt-get -qy update
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" upgrade crossbuild-essential-amd64 libncurses-dev libelf-dev libssl-dev make fakeroot bison flex bc rsync neofetch wget zstd
apt-mark hold linux-image-amd64

mkdir -p kernel/linux-upstream-6.2.0-rc5
cd $_

wget https://raw.githubusercontent.com/xanmod/linux/6.1/CONFIGS/xanmod/gcc/config_x86-64-v3
mv -v config_x86-64-v3 /boot/config-6.0.0-6-amd64
wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz

echo 'Extracting archive...'
tar -zxf linux-master.tar.gz --strip-components=1
rm linux-master.tar.gz

yes '' | make localmodconfig
make menuconfig

echo -e 'Compiling kernel...\n'
make -j7 deb-pkg
cd
dpkg -i ~/kernel/linux-image-6.2.0-*.deb
rm -R kernel
apt-get -qy -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" remove --purge linux-image-amd64 linux-image-6.0.0-6-amd64
update-grub2
sed -i 's/set timeout=5/set timeout=1/' /boot/grub/grub.cfg
apt-get autoremove
apt-get -qy clean

printf '\nEzKernel has installed: '; dpkg -l | grep linux-image | awk '{print$2}'
echo -e '\nPress enter to reboot'; read
reboot
