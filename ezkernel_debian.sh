#!/usr/bin/env bash

#   _______
#   |__ __|
#     ||horbits
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
    printf '\n\n\e[31m [WARNING]\e[0m %s\n\n' "$*" >&2
    exit 1
}

info() {
    printf '\n\e[32m [INFO]\e[0m %s\n\n' "$*"
}

restore_cursor() {
    	[[ -t 1 ]] && tput cnorm
}

abort() {
	restore_cursor
    fatal "process aborted by user."
}
trap restore_cursor EXIT
trap abort INT TERM QUIT

os_release() {
    awk -F= '/^ID=/{gsub(/"/,""); print tolower($2)}' /etc/os-release | cut -d- -f1
}

DISTRO=$(os_release)

declare -A KRNL_GROUP # map each distro to its required kernel compilation dependencies
KRNL_GROUP[debian]="build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex rsync debhelper python3"

case "$DISTRO" in
    debian)
    	UPDATE=(apt-get update -qq)
    	PM=(apt-get install -y --no-install-recommends)
    	LIST_CMD=(apt-get install --dry-run -qq)
	;;
    *)
        fatal "unsupported distribution: $DISTRO."
    ;;
esac

#intro
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

case "${DISTRO:-}" in
    debian)
		printf "\n\n Welcome %s, to eZkernel for %s.\n\n The latest Linux kernel available in mainline (kernel.org) or sid (deb.debian.org), will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
		;;
    *)
        fatal "unsupported distribution: $DISTRO."
        ;;
esac	

# path variables
WORKDIR="${HOME:-/root}/kernel"
KVER= URL= SRCDIR= TARBALL=	# initialise, so tu use later ouside function

# choice of kernel sources
case "${DISTRO:-}" in
    debian)
        printf " Which kernel sources do you want to use:\n\n"
        choose_source(){
    		while true; do
        		printf "\r\033[2K upstream master snapshot (1) or latest in sid/debian (2) [1/2]: "
        		read -n1 -s -r choice
	        case $choice in
            	1)  # upstream master snapshot
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
                	URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"
                	SRCDIR="${WORKDIR}/linux-upstream-${KVER}"
                	TARBALL="${SRCDIR}/linux-master.tar.gz"
                	printf "\n\n"
                	return
                	;;
            	2)  # Debian sid (latest 6.1x)
                	KVER=$(curl -s "https://packages.debian.org/sid/kernel/" | grep -oP '\d+\.\d+\.\d+-\d+' | grep '^6\..*-1$' | sort -V | tail -n1 | sed 's/-.*//')
                	URL="http://deb.debian.org/debian/pool/main/l/linux/linux_${KVER}.debian.tar.xz"
                	SRCDIR="${WORKDIR}/linux-debian-${KVER}"
                	TARBALL="${SRCDIR}/linux_${KVER}.orig.tar.xz"
                	printf "\n\n"
                	return
                	;;
            	*)  printf "\nInvalid key—try again.\n" ;;
        	esac
    		done
		}
		choose_source
        ;;
esac

# kernel version check
printf " Checking kernels versions... please wait"

"${UPDATE[@]}" >/dev/null 2>&1 || fatal " no internet connection detected."

if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
    "${PM[@]}" curl wget >/dev/null 2>&1
fi

printf "\r%-*s\n\n" "$COLUMNS" " Checking kernels versions... done."
printf " Current kernel version: %s\n It will be updated to:  %s\n\n" "$(uname -r)" "$KVER"

while true; do
    printf "\r\033[2K Press Enter to continue or Ctrl+C to cancel."
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # continue if Enter was pressed
done

# packages install with progress bar
check_deps() {
    printf "\n\n Checking compilation dependencies for %s …\n\n" "$DISTRO"
	local -a pkgs
    case "$DISTRO" in
        debian)
            # inherit the current locale not to block install
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            {
              echo "locales locales/default_environment_locale select $current_locale"
              echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8"
            } | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            
            mapfile -t pkgs < <("${LIST_CMD[@]}" ${KRNL_GROUP[$DISTRO]} | awk '/^Inst / {print $2}')
            ;;
	esac

    local -i total=${#pkgs[@]} ok=0 i=0 pct=-1 filled
    local -r BAR_MAX=30 BAR_CHAR='|'
    local -r bar=$(printf "%${BAR_MAX}s" '' | tr ' ' "$BAR_CHAR")
    local -i max_len=0
    for q in "${pkgs[@]}"; do (( ${#q} > max_len )) && max_len=${#q}; done

    for p in "${pkgs[@]}"; do
        ((i++))
        dpkg -s "$p" &>/dev/null || "${PM[@]}" "$p" &>/dev/null && ((ok++))

        filled=$(( i * 100 / total ))
        ((filled==pct)) && continue
        pct=$filled

        # fixed-length bar
        printf "\r Progress: %3d%% [%*s%s] Verifying: %-*s%*s" \
               "$pct" \
               $(( filled*BAR_MAX/100 )) \
               "$(printf '%*s' $((filled*BAR_MAX/100)) '' | tr ' ' "$BAR_CHAR")" \
               "$(printf '%*s' $((BAR_MAX - filled*BAR_MAX/100)) '')" \
               $((max_len-55)) "$p" \
               $((max_len-55-${#p}>0?max_len-55-${#p}:0)) ''
    done
    printf "\r Progress: 100%% [%-*s] Installed %d new package(s).\n\n" \
           "$BAR_MAX" "$bar" "$ok"
}

check_deps

# prepare build env
read -r -d '' FLAVOUR_MAP <<'EOF'
upstream	latest upstream kernel snapshot
debian		latest Debian/sid kernel source
EOF

source_download(){
    while IFS=' ' read -r key text; do
        case $SRCDIR in
        *"$key"*) printf " Downloading %s…\n\n" "$text"; return ;; # directory-independent message, see flavour map
        esac
    done <<<"$FLAVOUR_MAP"
}

source_download

mkdir -p "${SRCDIR}"
cd "${SRCDIR}"

if ! wget -q --show-progress "$URL" -O "${TARBALL}"; then
    fatal "failed to download kernel source."
fi

printf "\n Extracting kernel sources…\n\n"
case "$URL" in
    *.tar.gz)  tar -xzf "${TARBALL}" --strip-components=1 ;;
    *.tar.xz)  tar -xJf "${TARBALL}" --strip-components=1 ;;
esac
rm -f "${TARBALL}"

# cpu variables
MAXJOBS=$(nproc) # use max cores, change to MAXJOBS=8 to limit cpu parallelism, avoid OOM on tiny VMs
JOBS=$(nproc)
(( JOBS > MAXJOBS )) && JOBS=$MAXJOBS

# kernel compilation
if ! (yes '' | make localmodconfig && make menuconfig); then
    fatal "error generating kernel config"
fi
if ! time { \
        make -j"$MAXJOBS" bindeb-pkg && \
        dpkg -i "${WORKDIR}"/*.deb; \
		printf "\n\n eZkernel compilation successful for version: %s\n\n Compilation time :\n" "$KVER"
    }; then
    fatal "kernel compilation or package installation failed."
fi

# cleanup and reboot
cd ~
rm -rf "${WORKDIR}"

reboot_system(){
	printf "\n System will reboot now.\n\n"
	while : ; do
    read -r -s -n1 -p $' Press Enter to continue or Ctrl+C to cancel.' REPLY
    if [[ -z "$REPLY" ]]; then # Enter only, no other key
        break
    fi
	done

    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    else
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    fi

    update-grub >/dev/null 2>&1 || fatal "failed to update grub."

	printf "\n\n"
	for i in {5..1}; do
    	printf "\r\033[2K Rebooting in %d second%s..." "$i" $([ "$i" -eq 1 ] && echo "" || echo "s")
    	sleep 1
	done
    /sbin/reboot
}
reboot_system
