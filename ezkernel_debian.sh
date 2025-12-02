#!/bin/bash
#
#    _______
#   \_   _/
#     |_|horbits
#
#   eZkernel for Debian
#   Interactive Linux kernel compilation and installation script
# ------------------------------------------------------------

clear

printf "\n\nWelcome %s, to eZkernel for Debian.\n\n" "$USER"
printf "The latest mainline Linux kernel from www.kernel.org will be compiled and installed.\n\n"
printf "Checking kernels versions... please wait"
apt-get update -qq || {
    printf "\n\nConnection error. Exiting.\n"
    exit 1
}
apt-get install -y curl > /dev/null 2>&1

KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
max_len=80
printf "\r%-*s\n\n" "$max_len" "Checking kernels versions... done."

printf "Current kernel version: %s\nIt will be updated to:  %s\n\n" \
       "$(uname -r)" "$KVER"
printf "Press Enter to continue or Ctrl+C to cancel.\n"
read -rp '' && printf "Checking compilation dependencies...\n\n"

pkgs=(
    build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev
    libssl-dev bison bc flex rsync debhelper python3 wget
)

sum=${#pkgs[@]}
pkg_len=0

for q in "${pkgs[@]}"; do
    (( ${#q} > pkg_len )) && pkg_len=${#q}
done

i=0 ok=0
for p in "${pkgs[@]}"; do
    ((i++))
    dpkg -s "$p" &>/dev/null || {
        apt-get install -y --no-install-recommends "$p" &>/dev/null && ((ok++))
    }
    printf "\rProgress: %3d%% [%-20s] %-*s" \
           $((i*100/sum)) \
           "$(printf '|%.0s' $(seq 1 $((i*20/sum))))" \
           "$pkg_len" "$p"
done

printf "\rProgress: 100%% [%-20s] Installed %d new package(s).\n\n" \
       "$(printf '|%.0s' $(seq 1 20))" "$ok"

printf "Downloading kernel sources...\n\n"

mkdir -p "kernel/linux-upstream-$KVER"
cd "$_"

wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz
printf 'Extracting kernel sources...\n\n'
tar -zxf *.gz --strip-components=1
rm  *.gz

yes '' | make localmodconfig
make menuconfig && (
    time make -j"$(nproc)" bindeb-pkg &&
    dpkg -i ~/kernel/*.deb &&
    printf "\n\neZkernel compilation successful for version: %s\n" "$KVER"
) && reboot_system(){
    printf "\nSystem will reboot now.\n\nPress Enter to continue or Ctrl+C to cancel"
    read -rp '' && cd && rm -rf ~/kernel && {
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub ||
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    } && update-grub >/dev/null 2>&1 && reboot
} && reboot_system || (
    printf "\n\nCompilation or installation error. Exiting.\n\n"
    exit 1
)

