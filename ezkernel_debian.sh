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

(if (return 0 2>/dev/null); then return 0; fi)

[[ $EUID -eq 0 ]] || { echo " This script must be run as root (or sudo)" >&2; exit 1; }

#set -euo pipefail

fatal() {
    printf '\n\e[31m [WARNING]\e[0m %s\n\n' "$*" >&2
    exit 1
}

info() {
    printf '\n\e[32m [INFO]\e[0m %s\n\n' "$*"
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

printf "\n\n Welcome %s, to eZkernel for %s.\n\n The latest mainline Linux kernel from www.kernel.org will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
printf " Checking kernels versions... please wait"

"${UPDATE[@]}" >/dev/null 2>&1 || fatal " no internet connection detected."

if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
    "${PM[@]}" curl wget >/dev/null 2>&1
fi

# configurable variables
KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
WORKDIR="${HOME:-/root}/kernel"
SRCDIR="${WORKDIR}/linux-upstream-${KVER}"
TARBALL="${SRCDIR}/linux-master.tar.gz"
MAXJOBS=$(nproc) # MAXJOBS=8 limit cpu parallelism (avoid OOM on tiny VMs)
JOBS=$(nproc)
(( JOBS > MAXJOBS )) && JOBS=$MAXJOBS

max_len=80
printf "\r%-*s\n\n" "$max_len" " Checking kernels versions... done."

printf " Current kernel version: %s\n It will be updated to:  %s\n\n" "$(uname -r)" "$KVER"

while true; do
    printf "\r\033[2K Press Enter to continue or Ctrl+C to cancel."
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # break if Enter was pressed
done

printf "\n\n Checking compilation dependencies...\n\n"

pkgs=(build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex make rsync debhelper python3)
sum=${#pkgs[@]}
pkg_len=0
for q in "${pkgs[@]}"; do
    (( ${#q} > pkg_len )) && pkg_len=${#q}
done

i=0 ok=0
for p in "${pkgs[@]}"; do
    ((i++))
    dpkg -s "$p" &>/dev/null || {
        "${PM[@]}" "$p" &>/dev/null && ((ok++))
    }
	printf "\r Progress: %3d%% [%-40s] %-*s" $((i*100/sum)) "$(printf '|%.0s' $(seq 1 $((i*40/sum))))" "$pkg_len" "$p"
done

#install_deps() {

#    # apply terminal protection from keyboard input
#    local saved_tty
#    saved_tty=$(stty -g 2>/dev/null) || saved_tty=""
#    if [[ -n "$saved_tty" ]]; then
#        trap 'stty "$saved_tty" 2>/dev/null; trap - EXIT INT' EXIT INT
#        stty -echo -icanon min 0 time 0 2>/dev/null
#    fi

#    printf "\n\n Checking compilation dependencies...\n\n"
#    IFS=' ' read -r -a packages <<< "${KRNL_GROUP[$DISTRO]}"
#    local sum=${#packages[@]} pkg_len=0 i=0 ok=0
#    for q in "${packages[@]}"; do
#        (( ${#q} > pkg_len )) && pkg_len=${#q}
#    done
#    for p in "${packages[@]}"; do
#        ((i++))
#        dpkg -s "$p" &>/dev/null || {
#            "${PM[@]}" "$p" &>/dev/null && ((ok++))
#        }
#		printf "\rProgress: %3d%% [%-40s] %-*s" $((i*100/sum)) "$(printf '|%.0s' $(seq 1 $((i*40/sum))))" "$pkg_len" "$p"
#    done

#    # restore terminal settings
#    if [[ -n "$saved_tty" ]]; then
#        stty "$saved_tty" 2>/dev/null
#        trap - EXIT INT
#    fi

#    printf "\r Progress: 100%% [%-40s] Installed %d new package(s).\n\n" "$(printf '|%.0s' $(seq 1 40))" "$ok"
#}

#install_deps

printf "\r Progress: 100%% [%-40s] Installed %d new package(s).\n\n" "$(printf '|%.0s' $(seq 1 40))" "$ok"

#printf " Downloading kernel sources...\n\n"
#mkdir -p "kernel/linux-upstream-$KVER"
#cd "$_"
#wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz || fatal " failed to download kernel sources."

#printf " Extracting kernel sources...\n\n"
#tar -zxf *.gz --strip-components=1
#rm  *.gz

mkdir -p "${SRCDIR}"
cd "${SRCDIR}"
printf " Downloading latest upstream kernel snapshot…"
if ! wget -q --show-progress -O "${TARBALL}" \
        "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"; then
    fatal "failed to download kernel source."
fi
printf "\n Extracting kernel sources…\n\n"
tar -xzf "${TARBALL}" --strip-components=1
rm -f "${TARBALL}"

# kernel comppilation
#yes '' | make localmodconfig
#make menuconfig && (
#    time make -j"$(nproc)" bindeb-pkg &&
#    dpkg -i ~/kernel/*.deb &&
#    printf "\n\n eZkernel compilation successful for version: %s\n" "$KVER"
#)  || fatal "compilation or installation error."

make -s localmodconfig
make menuconfig
if ! time { \
        make -j"$JOBS" bindeb-pkg && \
        dpkg -i "${WORKDIR}"/*.deb; \
		printf "\n\n eZkernel compilation successful for version: %s\n\n" "$KVER"
    }; then
    fatal "kernel compilation or package installation failed."
fi

abort() {
    fatal "aborted by user – no reboot performed."
}
trap abort SIGINT SIGTERM

reboot_system(){
	printf " System will reboot now.\n\n"
	while : ; do
    read -r -s -n1 -p $' Press Enter to continue or Ctrl+C to cancel.' REPLY
    printf '\r\033[2K' # clear the prompt line
    if [[ -z "$REPLY" ]]; then # Enter only,no other key
        break
    fi
	done
	
    cd ~
    rm -rf "${WORKDIR}"

    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    else
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    fi

    update-grub >/dev/null 2>&1 || fatal "failed to update grub."
	
	for i in {5..1}; do
    	printf "\r\033[2K Rebooting in %d second%s..." "$i" $([ "$i" -eq 1 ] && echo "" || echo "s")
    	sleep 1
	done
	
    /sbin/reboot
}

#    while true; do
#    printf '\r\033[2K'
#    read -n1 -s -r -p ' Press Enter to continue or Ctrl+C to cancel.'
#
#    if (( $? != 0 )); then # exit if Ctrl+C was pressed
#        exit 1
#    fi
#    if [[ -z "$REPLY" ]]; then # break if Enter was pressed
#        break
#    fi
#    done

#    cd && rm -rf ~/kernel && {
#        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub ||
#        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
#    } && update-grub >/dev/null 2>&1 && reboot
#}

reboot_system



