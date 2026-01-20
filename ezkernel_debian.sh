#!/usr/bin/env bash

#	_______
#   \_   _/
#     |_|horbits
#
#    eZkernel for Debian
#    Interactive Linux kernel compilation and installation script
# ----------------------------------------------------------------#
#    Installs the latest mainline Linux kernel from www.kernel.org
# 
# ----------------------------------------------------------------#

if [[ "$(id -u)" -ne 0 ]]; then
    printf "\n This script must be run as root. Use sudo.\n"
    exit 1
fi

set -euo pipefail

fatal() {
    printf "\n [WARNING] %s Exiting...\n\n" "$*" >&2 # critical error message
    exit 1
}

os_release() {
    awk -F= '/^ID=/{gsub(/"/,""); print tolower($2)}' /etc/os-release | cut -d- -f1
}

DISTRO=$(os_release)

case "$DISTRO" in
    debian)
    	UPDATE=(apt-get update -qq)
    	PM=(apt-get install -y --no-install-recommends)
    	LIST_CMD=(apt-get install --dry-run -qq)
	;;
    *)
        fatal " unsupported distribution: $DISTRO."
    ;;
esac

declare -A KRNL_GROUP # map each distro to its required kernel compilation dependencies
KRNL_GROUP[debian]="build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex rsync debhelper python3"

clear
echo
case "$DISTRO" in
        debian)
            cat << 'ART'
               _,met$$$$$gg.
            ,g$$$$$$$$$$$$$$$P.
          ,g$$P"        "\""Y$$.".
         ,$$$P'              `$$$:
        'd$$P       ,ggs.     `$$b:
        `d$$'     ,$P"'   .    $$$:
        `d$$      d$'     ,    $$$P
        `$$:      $$.   -    ,d$$'
        `$$;      Y$b._   _,d$P'
        `Y$$.    `.`"Y$$$$P"'
         `$$b      "-.__ 
          `Y$$
           `Y$$.
             `$$b.
               `Y$$b.
                  `"Y$b.
                      `"\""
ART
        ;;
esac

printf " Welcome %s, to eZkernel for %s.\n\n The latest mainline Linux kernel from www.kernel.org will be compiled and installed.\n\n" "$USER" "$DISTRO"
printf " Checking kernels versions... please wait"

"${UPDATE[@]}" >/dev/null 2>&1 || fatal " no internet connection detected."

if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
    "${PM[@]}" curl wget >/dev/null 2>&1
fi

KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
max_len=80
printf "\r%-*s\n\n" "$max_len" " Checking kernels versions... done."

printf " Current kernel version: %s\n It will be updated to:  %s\n\n" "$(uname -r)" "$KVER"

while true; do
    printf "\r\033[2K Press Enter to continue or Ctrl+C to cancel."
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # break if Enter was pressed
done

#printf "\n\n Checking compilation dependencies...\n\n"
#
#pkgs=(
#    build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev
#    libssl-dev bison bc flex rsync debhelper python3 wget
#)
#
#sum=${#pkgs[@]}
#pkg_len=0
#
#for q in "${pkgs[@]}"; do
#    (( ${#q} > pkg_len )) && pkg_len=${#q}
#done
#
#i=0 ok=0
#for p in "${pkgs[@]}"; do
#    ((i++))
#    dpkg -s "$p" &>/dev/null || {
#        apt-get install -y --no-install-recommends "$p" &>/dev/null && ((ok++))
#    }
#    printf "\rProgress: %3d%% [%-40s] %-*s" \
#           $((i*100/sum)) \
#           "$(printf '|%.0s' $(seq 1 $((i*40/sum))))" \
#           "$pkg_len" "$p"
#done

install_deps() {

#    # apply terminal protection from keyboard input
#    local saved_tty
#    saved_tty=$(stty -g 2>/dev/null) || saved_tty=""
#    if [[ -n "$saved_tty" ]]; then
#        trap 'stty "$saved_tty" 2>/dev/null; trap - EXIT INT' EXIT INT
#        stty -echo -icanon min 0 time 0 2>/dev/null
#    fi

    printf "\n\n Checking compilation dependencies...\n\n"
    local packages=(${KRNL_GROUP[$DISTRO]})
    # progress bar and installation logic
    local sum=${#packages[@]} pkg_len=0
    for q in "${packages[@]}"; do
        (( ${#q} > pkg_len )) && pkg_len=${#q}
    done

	local i=0 ok=0
    for p in "${packages[@]}"; do
        ((i++))
        dpkg -s "$p" &>/dev/null || {
            "${PM[@]}" "$p" &>/dev/null && ((ok++))
        }
		printf "\rProgress: %3d%% [%-40s] %-*s" $((i*100/sum)) "$(printf '|%.0s' $(seq 1 $((i*40/sum))))" "$pkg_len" "$p"
    done

#    # restore terminal settings
#    if [[ -n "$saved_tty" ]]; then
#        stty "$saved_tty" 2>/dev/null
#        trap - EXIT INT
#    fi

    printf "\r Progress: 100%% [%-40s] Installed %d new package(s).\n\n" "$(printf '|%.0s' $(seq 1 40))" "$ok"
}

install_deps

printf " Downloading kernel sources...\n\n"
mkdir -p "kernel/linux-upstream-$KVER"
cd "$_"
wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz || fatal " failed to download kernel sources."

printf " Extracting kernel sources...\n\n"
tar -zxf *.gz --strip-components=1
rm  *.gz

# kernel comppilation
yes '' | make localmodconfig
make menuconfig && (
    time make -j"$(nproc)" bindeb-pkg &&
    dpkg -i ~/kernel/*.deb &&
    printf "\n\n eZkernel compilation successful for version: %s\n" "$KVER"
)  || fatal " compilation or installation error."

reboot_system(){
	printf "\n\n System will reboot now.\n\n"
    while true; do
    printf '\r\033[2K'
    read -n1 -s -r -p ' Press Enter to continue or Ctrl+C to cancel.'

    if (( $? != 0 )); then # exit if Ctrl+C was pressed
        exit 1
    fi
    if [[ -z "$REPLY" ]]; then # break if Enter was pressed
        break
    fi
    done
	
    cd ~
    rm -rf ~/kernel

    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    else
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    fi

    update-grub >/dev/null 2>&1 || fatal " failed to update grub."
    reboot
}

#    cd && rm -rf ~/kernel && {
#        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub ||
#        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
#    } && update-grub >/dev/null 2>&1 && reboot
#}

reboot_system

#[[ ${BASH_SOURCE[0]} == "$0" ]] && install_deps "$@" # run only when executed, not sourced




