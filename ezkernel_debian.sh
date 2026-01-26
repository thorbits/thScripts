#!/usr/bin/env bash

#   _______
#   |__ __|
#     ||horbits
#
#    eZkernel for arch/debian
#    Interactive Linux kernel compilation and installation script
# -------------------------------------------------------------------#
#    Compile the latest mainline Linux kernel snapshot (arch/debian)
#    or the latest kernel in sid (debian).
# -------------------------------------------------------------------#

(if (return 0 2>/dev/null); then return 0; fi)

[[ $EUID -eq 0 ]] || { echo " This script must be run as root (or sudo)" >&2; exit 1; }

#set -euo pipefail

fatal() {
    printf '\n\n\e[31m [WARNING]\e[0m %s\n\n' "$*" >&2
    exit 1
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
#KRNL_GROUP[arch]="base-devel bc bison flex libelf ncurses openssl python rsync zlib"
KRNL_GROUP[arch]="base-devel bc cpio gettext libelf pahole perl python rust rust-bindgen rust-src tar xz zstd"
KRNL_GROUP[debian]="build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex rsync debhelper python3"

case "$DISTRO" in
    arch)
    	UPDATE=(pacman -Sy)
    	PM=(pacman -S --needed --noconfirm)
    	LIST_CMD=(pacman -Sp --print-format '%n')
	;;
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
        arch)
            cat << 'ART'
                      .o+`
                     `ooo/
                    `+oooo:
                   `+oooooo:
                   -+oooooo+:
                 `/:-:++oooo+:
                `/++++/+++++++:
               `/++++++++++++++:
              `/+++ooooooooooooo/`
             ./ooosssso++osssssso+`
            .oossssso-````/ossssss+`
           -osssssso.      :ssssssso.
          :osssssss/        osssso+++.
         /ossssssss/        +ssssooo/-
       `/ossssso+/:-        -:/+osssso+-
      `+sso+:-`                 `.-/+oso:
     `++:.                           `-/+/
     .`                                 `/
ART
        ;;
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
	arch)
		printf "\n\n Welcome %s, to eZkernel for %s.\n\n The latest Linux kernel available in mainline (kernel.org) or cachyos/rc (aur.archlinux.org), will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
		;;
    debian)
		printf "\n\n Welcome %s, to eZkernel for %s.\n\n The latest Linux kernel available in mainline (kernel.org) or sid (deb.debian.org), will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
		;;
    *)
        fatal "unsupported distribution: $DISTRO."
        ;;
esac	

"${UPDATE[@]}" >/dev/null 2>&1 || fatal "no internet connection detected."
if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
	"${PM[@]}" curl wget >/dev/null 2>&1
fi

# path variables
WORKDIR="/var/tmp/kernel"
KCFG=false
KVER= URL= SRCDIR= TARBALL=	MAKEFLAGS= # initialise, to use later ouside function

# sources selection
printf " Which kernel sources do you want to use,\n\n"
case "${DISTRO:-}" in
	arch)
        choose_source(){
    		while true; do
        		printf $'\r\033[2K upstream master snapshot (1) or latest in cachyos/rc (2) [1/2]: '
        		read -n1 -s -r choice
	        case $choice in
            	1)  # upstream master snapshot
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
                	URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"
                	SRCDIR="${WORKDIR}/linux-upstream-${KVER}"
                	TARBALL="${SRCDIR}/linux-master.tar.gz"
                	printf "\n\n Selected: upstream master snapshot\n\n"
                	return
                	;;
            	2)  # cachyos/rc
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
                	URL="https://github.com/torvalds/linux/archive/refs/tags/v${KVER}.tar.gz"
					URL1="https://aur.archlinux.org/cgit/aur.git/snapshot/linux-cachyos-rc.tar.gz"
                	SRCDIR="${WORKDIR}/linux-cachyos-${KVER}"
                	TARBALL="${SRCDIR}/v${KVER}.tar.gz"
					TARKCFG="${SRCDIR}/linux-cachyos-rc.tar.gz"
                	printf "\n\n Selected: cachyos/rc\n\n"
					KCFG=true
                	return
                	;;
            	*)  ;;
			esac
			done
		}
		choose_source
		;;
    debian)
        choose_source(){
    		while true; do
        		printf $'\r\033[2K upstream master snapshot (1) or latest in debian/sid (2) [1/2]: '
        		read -n1 -s -r choice
	        case $choice in
            	1)  # upstream master snapshot
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
                	URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"
                	SRCDIR="${WORKDIR}/linux-upstream-${KVER}"
                	TARBALL="${SRCDIR}/linux-master.tar.gz"
                	printf "\n\n Selected: upstream master snapshot\n\n"
                	return
                	;;
            	2)  # debian/sid
                	KVER=$(curl -s "https://packages.debian.org/sid/kernel/" | grep -oP '\d+\.\d+\.\d+-\d+' | grep '^6\..*-1$' | sort -V | tail -n1 | sed 's/-.*//')
                	URL="http://deb.debian.org/debian/pool/main/l/linux/linux_${KVER}.orig.tar.xz"
                	SRCDIR="${WORKDIR}/linux-debian-${KVER}"
                	TARBALL="${SRCDIR}/linux_${KVER}.orig.tar.xz"
                	printf "\n\n Selected: debian/sid\n\n"
                	return
                	;;
            	*)  ;;
        	esac
    		done
		}
		choose_source
        ;;
esac

# kernel version check
printf " Checking kernels versions... please wait" && sleep 2
printf '\r%-*s\n\n Current kernel version: %s\n It will be updated to:  %s\n\n' \
       "$COLUMNS" " Checking kernels versions... done." \
       "$(uname -r)" "$KVER"

while true; do
    printf $'\r\033[2K Press Enter to continue or Ctrl+C to cancel'
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # continue if Enter was pressed
done

# packages install with progress bar
check_deps() {
    printf "\n\n Checking compilation dependencies for %s...\n\n" "$DISTRO"
	local -a pkgs
    case "$DISTRO" in
		arch)
			mapfile -t pkgs < <("${LIST_CMD[@]}" ${KRNL_GROUP[$DISTRO]})
			;;
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
        printf "\r Progress: %3d%% [%*s%s] Verifying/installing: %-*s%*s" \
               "$pct" \
               $(( filled*BAR_MAX/100 )) \
               "$(printf '%*s' $((filled*BAR_MAX/100)) '' | tr ' ' "$BAR_CHAR")" \
               "$(printf '%*s' $((BAR_MAX - filled*BAR_MAX/100)) '')" \
               $((max_len-60)) "$p" \
               $((max_len-60-${#p}>0?max_len-60-${#p}:0)) ''
    done
	printf '\r%-*s\r Progress: 100%% [%-*s] Installed %d new package(s).\n\n' "$COLUMNS" '' "$BAR_MAX" "$bar" "$ok"
}

check_deps

# prepare build env
declare -A FLAVOUR_MAP=(
    [upstream]="latest upstream kernel snapshot"
    [debian]="latest debian/sid kernel source"
	[cachyos]="latest cachyos/rc kernel source"
)

manage_sources() {
    local msg="" key
    for key in "${!FLAVOUR_MAP[@]}"; do
        if [[ "$SRCDIR" =~ $key ]]; then
            msg=${FLAVOUR_MAP[$key]}
            break
        fi
    done
    printf " Downloading %s...\n\n" "$msg" # directory-independent message, see flavour map
    mkdir -p "$SRCDIR"
	chmod 1777 "$SRCDIR"
    cd "$SRCDIR"
    wget -q --show-progress -O "$TARBALL" "$URL" || fatal "error downloading kernel sources."
	if [[ ${KCFG} == true ]]; then
		printf "\n Downloading latest cachyos config file...\n\n"
        wget -q --show-progress -O "$TARKCFG" "$URL1" || fatal "error downloading cachyos config."
    fi
	printf "\n Extracting kernel sources...\n\n"
	case "$TARBALL" in
    	*.tar.gz)  tar -xzf "${TARBALL}" --strip-components=1 ;;
    	*.tar.xz)  tar -xJf "${TARBALL}" --strip-components=1 ;;
	esac
	rm -f "$TARBALL"
	if [[ "$KCFG" == true ]]; then
    	printf " Extracting cachyos config...\n\n"
		tar -xzf "${TARKCFG}" --strip-components=1
		cp config .config
#		tar -xOf "$TARKCFG" $(tar -tf "$TARKCFG" | grep -E '/config$') > .config
	fi
	rm -f "$TARKCFG"
}

manage_sources

# cpu variables
choose_cores() {
    local cores total
    total=$(nproc)
    printf ' How many CPU cores of the system (in %%) do you want to use for compilation?\n\n'
    printf ' 25%% : %d cores   50%% : %d cores   100%% : %d cores\n\n' $((total/4)) $((total/2)) "$total"
    while read -rn1 -p ' Choose (1=25%%  2=50%%  3=100%%): ' choice; do
        case $choice in
            1) pct=25 ;;
            2) pct=50 ;;
            3) pct=100 ;;
            *) continue ;;
        esac
        cores=$(( total * pct / 100 ))
        MAKEFLAGS="-j$cores"
        printf "\n\n"
        return
    done
}

choose_cores

info() {
    printf "\n\e[32m [INFO]\e[0m eZkernel compilation successful for version: %s\n\n Compilation time: \n" "$*"
}

# kernel compilation
if [[ "$KCFG" == false ]]; then
    if ! (yes '' | make localmodconfig && make menuconfig); then
        fatal "error generating kernel config."
    fi
else
	if [[ ! -f ".config" || ! -r ".config" || ! -s ".config" ]]; then
        fatal "'config' file is missing, unreadable, or empty."
    fi
#	sed -i 's/^CONFIG_MODULES=y/CONFIG_MODULES=n/' .config
fi
case "$DISTRO" in
	arch)
		time { \
			# Run makepkg as regular user in a subshell
            if ! su "${SUDO_USER:-$USER}" -c "cd '$PWD' && MAKEFLAGS='$MAKEFLAGS' makepkg -s --noconfirm"; then
                fatal "error during kernel compilation process."
            fi
            pkgfile=$(find . -maxdepth 1 -name "*.pkg.tar.zst" -print -quit)
            if [[ -z "$pkgfile" ]]; then
                fatal "could not find built package"
            fi
            pacman -U --noconfirm "$pkgfile" || fatal "error installing the built package"
    		info "$KVER"
		} 2>&1
		;;
    debian)
		time { \
        	if ! make "$MAKEFLAGS" bindeb-pkg; then
				fatal "error during kernel compilation process."
			fi
        	dpkg -i "${WORKDIR}"/*.deb
			info "$KVER"
		} 2>&1
		;;
esac

#    		if ! make "$MAKEFLAGS" bzImage modules; then
#    			make modules_install install

# cleanup and reboot
cd ~
rm -rf "${WORKDIR}"

reboot_system(){
	printf "\n System must be rebooted to load the new kernel.\n\n"
	while : ; do
    read -r -s -n1 -p $' Press Enter to continue or Ctrl+C to cancel' REPLY
    if [[ -z "$REPLY" ]]; then # Enter only, no other key
        break
    fi
	done
	case "$DISTRO" in
		arch)
			if [ -d /boot/loader/entries ] && ls /boot/loader/entries/*.conf >/dev/null 2>&1; then
#				bootctl update
    			:
			elif command -v grub-mkconfig >/dev/null 2>&1; then
    			grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1 || fatal "failed to update grub."
			fi
			;;
        debian)
			if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        		sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    		else
        		echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    		fi
    		update-grub >/dev/null 2>&1 || fatal "failed to update grub."
			;;
	esac
	printf "\n\n"
	for i in {5..1}; do
    	printf "\r\033[2K Rebooting in %d second%s..." "$i" $([ "$i" -eq 1 ] && echo "" || echo "s")
    	sleep 1
	done
    /sbin/reboot
}

reboot_system
