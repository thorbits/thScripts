#!/usr/bin/env bash

#   _______
#   |__ __|
#     ||horbits
#
#    eZkernel for arch/debian
#    Interactive Linux kernel compilation and installation script
# -------------------------------------------------------------------#
#    Compile the latest mainline Linux kernel snapshot (arch/debian)
#
# -------------------------------------------------------------------#

(return 0 2>/dev/null) && { echo "Error: This script must be executed, do not source." >&2; return 1; }
[ "$(id -u)" -eq 0 ] || { echo "Error: This script must be run as root (sudo)" >&2; exit 1; }

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
KRNL_GROUP[arch]="base-devel bc cpio gettext libelf pahole perl python rust rust-bindgen rust-src tar xz zstd"
KRNL_GROUP[debian]="build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex rsync debhelper python3"

case "$DISTRO" in
    arch)
    	LIST_CMD=(pacman -Sp --print-format '%n')
		PM=(pacman -S --needed --noconfirm)
		PM_CHK=("pacman -Qq")
    	UPDATE=(pacman -Sy)
	;;
	debian)
    	LIST_CMD=(apt-get install --dry-run -qq)
		PM=(apt-get install -y --no-install-recommends)
		PM_CHK=(dpkg -s)
		UPDATE=(apt-get update -qq)
	;;
    *)
        fatal "unsupported distribution: $DISTRO."
    ;;
esac

#intro
clear; echo
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
printf "\n\n #%s#\n\n" "$(printf '%*s' "$(( $(tput cols) - 4 ))" '' | tr ' ' '-')"
case "${DISTRO:-}" in
	arch)
		printf " Welcome %s, to eZkernel for %s.\n\n The latest Linux kernel in mainline (kernel.org) or mainline + cachyos patch (github.com), will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
		;;
    debian)
		printf " Welcome %s, to eZkernel for %s.\n\n The latest Linux kernel in mainline or stable (kernel.org), will be will be sourced, compiled and installed.\n\n" "$USER" "$DISTRO"
		;;
esac	

"${UPDATE[@]}" >/dev/null 2>&1 || fatal "no internet connection detected."
if ! command -v curl >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
	"${PM[@]}" curl wget >/dev/null 2>&1
fi

choose_cores() {
    local cores total
    total=$(nproc)
    printf "\n\n How many CPU cores of the system (in %%) do you want to use for compilation\n\n"
    printf " 25%% : %d cores   50%% : %d cores   100%% : %d cores\n\n" $((total/4)) $((total/2)) "$total"
    while read -rn1 -p ' Choose (1=25%%  2=50%%  3=100%%): ' choice; do
        case $choice in
            1) pct=25 ;;
            2) pct=50 ;;
            3) pct=100 ;;
            *) continue ;;
        esac
        cores=$(( total * pct / 100 ))
        export MAKEFLAGS="-j$cores"
		echo
        return
    done
}

custom_config(){
	printf "\n Do you need to customize the kernel .config file?\n\n"
    KCFG=false # default fallback
    read -p " yes / no  [y/n]: " -n1 -r
    echo
    [[ $REPLY == [Yy] ]] && KCFG=true
}

# sources selection
printf " Which kernel sources do you want to use\n\n"
KMOD=false # default fallback
if [[ -n "${SUDO_USER}" ]]; then # home dir avoid tmpfs, permission issues
	WORKDIR=$(eval echo "~${SUDO_USER}/kernel-build")
else
	WORKDIR="${HOME}/kernel-build"
fi
case "${DISTRO:-}" in
	arch)
        choose_source(){
			KVER=$(curl -s https://www.kernel.org/finger_banner | awk 'NR==2 {print $NF}')
            URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"
			#export INSTALL_MOD_STRIP=1 # save space in /lib/modules
    		while true; do
        		printf $'\r\033[2K mainline (1)  mainline + cachyos patch (2)  [1/2]: '
        		read -n1 -r choice
	        case $choice in
            	1)  # upstream master snapshot
					SRCDIR="${WORKDIR}/linux-upstream"
					TARBALL="${SRCDIR}/linux-master.tar.gz"
					printf "\n\n Selected: mainline\n\n"
                	return
                	;;
            	2)  # cachyos-rc
					SRCDIR="${WORKDIR}/linux-cachyos"
					TARBALL="${SRCDIR}/linux-master.tar.gz"
					#CONFIG_URL="https://raw.githubusercontent.com/CachyOS/linux-cachyos/refs/heads/master/linux-cachyos-rc/config"
					PATCH_URL="https://raw.githubusercontent.com/CachyOS/kernel-patches/refs/heads/master/6.19/all/0001-cachyos-base-all.patch"
					PATCH="${SRCDIR}/0001-cachyos-base-all.patch"
					KMOD=true
                	printf "\n\n Selected: mainline + cachyos patch\n\n"
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
        		printf $'\r\033[2K mainline (1)  stable (2)  [1/2]: '
        		read -n1 -r choice
	        case $choice in
            	1)  # mainline
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '2s/^[^6]*//p')
                	URL="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz"
                	SRCDIR="${WORKDIR}/linux-upstream"
                	TARBALL="${SRCDIR}/linux-master.tar.gz"
                	printf "\n\n Selected: mainline\n\n"
                	return
                	;;
            	2)  # stable
                	KVER=$(curl -s https://www.kernel.org/finger_banner | sed -n '1s/^[^6]*//p')
                	URL="https://www.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz"
                	SRCDIR="${WORKDIR}/linux-stable"
                	TARBALL="${SRCDIR}/linux_${KVER}.tar.xz"
                	printf "\n\n Selected: stable\n\n"
                	return
                	;;
            	*)  ;;
        	esac
    		done
		}
		choose_source
        ;;
esac

printf " Checking kernels versions... please wait" && sleep 1
printf '\r%-*s\n\n Current kernel version: %s\n It will be updated to : %s\n\n' \
    "$COLUMNS" " Checking kernels versions... done." \
    "$(uname -r)" "$KVER"
while true; do
    printf $'\r\033[2K Press Enter to continue or Ctrl+C to cancel'
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # continue if Enter was pressed
done

check_deps() {
    printf "\n\n Checking compilation dependencies for %s...\n\n" "$DISTRO"
	# per package group, map all individual dependencies
	local -a pkgs
    case "$DISTRO" in
		arch)
			mapfile -t pkgs < <("${LIST_CMD[@]}" ${KRNL_GROUP[$DISTRO]} | grep -Fxvf <(pacman -Qq))
			;;
        debian)
            # inherit the current locale for install
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
	# fixed lengh progress bar
	local -i total=${#pkgs[@]} ok=0 i=0 pct=-1 filled
	local -r BAR_MAX=30 BAR_CHAR='|'
	local -r bar=$(printf "%${BAR_MAX}s" '' | tr ' ' "$BAR_CHAR")
	for p in "${pkgs[@]}"; do
    	((i++))
    	"${PM_CHK[@]}" "$p" &>/dev/null || "${PM[@]}" "$p" &>/dev/null && ((ok++))
    	filled=$(( i * 100 / total ))
    	((filled==pct)) && continue
    	pct=$filled
    	filled_len=$(( filled * BAR_MAX / 100 ))
    	empty_len=$(( BAR_MAX - filled_len ))
    	bar_filled=$(printf '%*s' $filled_len '' | tr ' ' "$BAR_CHAR")
    	bar_empty=$(printf '%*s' $empty_len '')
    	printf "\r Progress: %3d%% [%s%s] Verifying/installing: %s\033[K" \
           "$pct" \
           "$bar_filled" \
           "$bar_empty" \
           "$p"
	done
	printf '\r%-*s\r Progress: 100%% [%-*s] Installed %d new package(s).\n\n' "$COLUMNS" '' "$BAR_MAX" "$bar" "$ok"
}

# custom message for source and patch
declare -A FLAVOUR_MAP=(
    [upstream]="latest mainline sources"
    [stable]="latest stable sources"
	[cachyos]="latest cachyos patch"
)

manage_source() {
    local msg="" key
	if [[ ${KMOD} == true ]]; then
		msg=${FLAVOUR_MAP[upstream]}
	else
    	for key in "${!FLAVOUR_MAP[@]}"; do
	        if [[ "$SRCDIR" =~ $key ]]; then # directory-independent message, see flavour map
    	        msg=${FLAVOUR_MAP[$key]}
        	    break
        	fi
    	done
	fi
    printf " Downloading %s...\n\n" "$msg"
    mkdir -p "$SRCDIR"
    cd "$SRCDIR"
    wget -q --show-progress -O "$TARBALL" "$URL" || fatal "error downloading kernel sources."
	printf "\n Extracting kernel sources...\n\n"
	case "$TARBALL" in
    	*.tar.gz)  tar -xzf "${TARBALL}" --strip-components=1 ;;
    	*.tar.xz)  tar -xJf "${TARBALL}" --strip-components=1 ;;
	esac
	rm -f "$TARBALL"
}

manage_config() {
    printf " Generating kernel config...\n\n" && sleep 1
    if ! (yes '' | make localmodconfig); then
        fatal "error generating kernel config."
    fi
    if [[ "$KCFG" == true ]]; then
        if [[ "$DISTRO" == "arch" ]]; then
            make olddefconfig
        else
            make menuconfig
        fi
    fi
}

manage_patch() {
	[[ "$KMOD" == true ]] || return
    local msg=""
    msg=${FLAVOUR_MAP[cachyos]}
    printf " Downloading %s...\n\n" "$msg"
	#wget -q -O .config "$CONFIG_URL"
    wget -q --show-progress -O "$PATCH" "$PATCH_URL" || fatal "error downloading $PATCH."
    local STRIP_LEVEL="${1:-1}"
    if patch -p"${STRIP_LEVEL}" -R --dry-run -i "$PATCH" >/dev/null 2>&1; then
        fatal "patch already applied."
    fi
    if ! patch -p"${STRIP_LEVEL}" --dry-run -i "$PATCH" >/dev/null 2>&1; then
        fatal "patch does not apply cleanly, possible conflicts."
    fi
    if patch -p"${STRIP_LEVEL}" --no-backup-if-mismatch -i "$PATCH"; then
        printf "\n\e[32m [INFO]\e[0m CachyOS patch applied successfully for kernel %s\n\n" "$KVER"
    else
        fatal "patch application failed"
    fi
}

# cleanup and reboot
reboot_system(){
	cd ~ && rm -rf "${WORKDIR}" 
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
    			: # if necessary: bootctl update
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

script_opt() {
	# disable massive compile-time killers
	scripts/config --disable DEBUG_INFO
	scripts/config --disable DEBUG_INFO_BTF      # avoids slow 'pahole' processing
	scripts/config --disable LTO_CLANG           # LTO increases build time 2-5x
	scripts/config --disable LTO_GCC
	scripts/config --disable LTO_NONE            # explicitly select none if needed, or just disable the others
	# VM-specific: No Secure Boot needed, skip slow signing
	scripts/config --disable MODULE_SIG
	scripts/config --disable MODULE_SIG_ALL
	# skip compression overhead (VM CPU is precious, disk is cheap/fast enough)
	scripts/config --disable MODULE_COMPRESS     # faster 'make modules_install', faster module loading
	# disable kernel debugging features that slow compile (VMs don't need these)
	scripts/config --disable KCOV                # kernel coverage (slows compile significantly)
	scripts/config --disable KASAN               # address sanitizer (massive compile slowdown)
	scripts/config --disable KMSAN
	scripts/config --disable GCOV_KERNEL
	# fastest kernel image compression (VM boot is from virtio-blk/SCSI, decompression is fast anyway)
	#scripts/config --enable KERNEL_GZIP
	#scripts/config --disable KERNEL_ZSTD         # ZSTD compression is slow to build
	#scripts/config --disable KERNEL_XZ
	make olddefconfig
}

# main sequence
choose_cores
custom_config
check_deps
manage_source
manage_config
manage_patch

# kernel compilation
export LD=/usr/bin/ld.bfd # use GNU ld instead of ld.lld
export LDFLAGS="-fuse-ld=bfd"
export KCFLAGS="-g0 -O2 -fuse-ld=bfd"
export HOSTCFLAGS="-g0 -O2"

info() {
    printf "\n\e[32m [INFO]\e[0m eZkernel compilation successful for version: %s\n\n Compilation time: \n" "$*"
}

case "$DISTRO" in
	arch)
		time { \
			if ! make bzImage modules; then
                fatal "error during kernel compilation process."
            fi
            make modules_install install
    		info "$KVER"
		} 2>&1
		;;
    debian)
		time { \
        	if ! make bindeb-pkg; then
				fatal "error during kernel compilation process."
			fi
        	dpkg -i "${WORKDIR}"/*.deb
			info "$KVER"
		} 2>&1
		;;
esac
reboot_system
