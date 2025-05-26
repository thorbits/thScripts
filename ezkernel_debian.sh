#!/bin/bash
#
#	_______
#	\_   _/
#	  |_|horbits 
#
#	eZkernel for Debian

clear
printf "\n\nWelcome %s, to eZkernel for Debian.\n\nThe latest linux kernel from git.kernel.org will be compiled and installed.\n\n" "$(whoami)"

steps=3
step() {
    percent=$(( (($1 + 1) * 100) / steps ))
    printf "\rChecking kernels versions... (%d%%)" $percent
}

step 0
apt-get update -qq

step 1 || { echo -e "\n\nConnection error. Exiting.\n"; exit 1; }

apt-get install -y curl > /dev/null 2>&1

step 2
kver=$(curl -s https://www.kernel.org/ | grep -oP '(?<=<strong>)[^<]+(?=</strong>)' | head -n 2 | tail -n 1)

printf "\rChecking kernels versions... Done  \n\nCurrent kernel version: %s\nIt will be updated to:  %s\n\nPress Enter to continue or Ctrl+C to cancel.\n" "$(uname -r)" "$kver"

read && printf 'Checking compilation dependencies...\n\n'

pkgs="build-essential bison bc flex rsync libdw-dev libelf-dev libssl-dev zlib1g-dev libncurses-dev debhelper python3 wget"
total=$(echo "$pkgs" | tr ' ' '\n' | wc -l)
count=0
max_len=0

for p in $pkgs; do
    len=${#p}
    ((len > max_len)) && max_len=$len
done

format_str="\rProgress: %3d%% [%-20s] Now installing: %-${max_len}s"

for p in $pkgs; do
    if ! dpkg-query -W -f="${Status}\n" "$p" 2>/dev/null | grep -q "install ok"; then
        count=$((count + 1))
        percent=$((count * 100 / total))
        unit=$((percent / 5))
        bar=$(printf '#%.0s' $(seq 1 $unit))

        printf "$format_str" "$percent" "$bar" "$p"
        apt-get install -y --no-install-recommends "$p" > /dev/null 2>&1
    fi
done

printf "\rProgress: %3d%% [%-20s] Installed $total packages.\n\nDownloading kernel sources...\n\n" 100 "$bar"

mkdir -p "kernel/linux-upstream-$kver"
cd "$_"

wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz

printf 'Extracting kernel sources...\n\n'

tar -zxf linux-master.tar.gz --strip-components=1
rm linux-master.tar.gz

yes '' | make localmodconfig
make menuconfig && time {
    make -j$(nproc) bindeb-pkg
    dpkg -i ~/kernel/*.deb
    printf '\n\neZkernel compilation successful for version: %s\n\nCompilation time:\n' "$kver"
}

reboot_system() {
    echo -e "\nSystem will reboot now.\n\nPress Enter to continue or Ctrl+C to cancel"
    read -rp '' && cd
    rm -rf ~/kernel
    (sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub || echo "GRUB_TIMEOUT=1" >> /etc/default/grub)
    update-grub >/dev/null 2>&1
    reboot
}

reboot_system
