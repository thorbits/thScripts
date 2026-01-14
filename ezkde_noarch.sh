#!/usr/bin/env bash

#	_______
#	\_   _/
#	  |_|horbits 
#
#    eZkde for Arch / Debian / Fedora / OpenSuse
#    Automated KDE installation script
# ----------------------------------------------------------------
#    Install latest KDE 6.5.x (Wayland session) with audio support
#    (PipeWire) and a minimum of utilities.
# ----------------------------------------------------------------

if [[ "$(id -u)" -ne 0 ]]; then
    printf " This script must be run as root. Use sudo.\n"
    exit 1
fi

set -euo pipefail

# default tunables, see usage
BATCHSIZE=${BATCHSIZE:-1}
BAR_CHAR=${BAR_CHAR:-'|'}
EMPTY_CHAR=${EMPTY_CHAR:-' '}
USE_SWAP=false

usage() {
	local prog=${0##*/}
	cat <<-EOF
 Usage: $prog [options]

 options:
 -b	batch size for packages, default is 1
 -c	progress bar fill character, default is |
 -e	progress bar empty character, default is ' '
 -s create a 1gb swap file for install then removes it,
 	use if OOM error happens, default is false
 -h show help
 
 #-----------------------------------------------------#
 
EOF
}

fatal() { # critical error message
    printf "\n\n [WARNING] %s\n\n" "$*" >&2
    exit 1
}

os_release() {
    awk -F= '/^ID=/{gsub(/"/,""); print tolower($2)}' /etc/os-release | cut -d- -f1
}

DISTRO=$(os_release)

case "$DISTRO" in
    arch)
    UPDATE=(pacman -Syu --noconfirm)
    PM=(pacman -S --needed --noconfirm)
    LIST_CMD=(pacman -Sp --print-format '%n')
	;;
    debian)
    UPDATE=(apt-get update)
    PM=(apt-get install -y -o Dpkg::Options::="--force-confdef")
    LIST_CMD=(apt-get install --dry-run -qq)
	;;
    fedora)
    UPDATE=(dnf makecache)
    PM=(dnf install -y --best)
    LIST_CMD=(dnf install --assumeno)
	;;
    opensuse)
    UPDATE=(zypper ref)
    PM=(zypper install -y)
    LIST_CMD=(zypper install -y --dry-run)
	;;
    *)
	fatal " no supported linux distribution found (arch, debian, fedora, opensuse). Exiting."
	;;
esac

declare -A KDE_GROUP # map each distro to its native KDE (meta) packages
KDE_GROUP[arch]="plasma-meta dolphin konsole pipewire"
KDE_GROUP[debian]="plasma-workspace dolphin konsole pipewire sddm"
KDE_GROUP[fedora]="@kde-desktop"
#KDE_GROUP[fedora]="plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland dolphin"
KDE_GROUP[opensuse]="discover6 sddm patterns-kde-kde_plasma" #plasma6-desktop dolphin sddm sddm-config-wayland

# intro, DISTRO and UPDATE are set
clear
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
        fedora)
            cat << 'ART'
            .',;:ccccccccccccc:;,'.
          .;ccccccccccccccccccccccc;.
        .;ccccccccccc;.:dddl:.;ccccccc;.
       .:ccccccccccc;OWMKOOXMWd;ccccccc:.
      :cccccccccccc;KMMc;cc;xMMc;ccccccc:.
     :ccccccccccccc;MMM.;cc;;WW:;ccccccccc,
    .cccccccccccccc;MMM.;ccccccccccccccccc:
    .ccccccc;oxOOOo;MMM0OOk.;ccccccccccccc:
    .cccccc;0MMKxdd:;MMMkddc.;cccccccccccc;
    .cccc;XM0';cccc;MMM.;ccccccccccccccccc'
    .cccc;MMo;ccccc;MMW.;ccccccccccccccc;
    .cccc;0MNc.ccc.xMMd;ccccccccccccccc;
    .ccccc;dNMWXXXWM0:;ccccccccccccc:,.
    .cccccc;.::odl::.;cccccccccccc:,.
    ;cccccccccccccccccccccccc:;,.
    ;:cccccccccccccccccccc:;,.
ART
        ;;
        opensuse)
            cat << 'ART'
            ,.,ccc,.,                                 
         .,:lloooooc;.
       ,ool'    oo,  ;oo:
     .lo'       oo.     oo:
    .oo.        oo.      oo:
    :ol         oo.      'oo
    :oo.oooooooooo.      .oo.
    .oo                  .oo.
     ;oo.                .oo.
        "ooc,',,,,,,,,,,:ooc,,,,,,,,,,,
           ':cooooooooooooooooooooooooool;.
                        .oo.             .oo;
                       .oo.                ooo.
                       .oo.    'oooooooooooo:col
                       .oo'    'oo           col
                        coo    'oo           col'
                         coc   'oo          .lo,
                          `oo, 'oo        .:oo
                            'oo;ocoooooco;oo
                                `''"cc'"'      
ART
        ;;
esac

printf "\n\n #-------------------------------------------------#\n\n Welcome %s, to eZkde for %s.\n\n The latest version of KDE 6.5.x (Wayland session)\n will be installed with audio support (Pipewire)\n SDDM and a minimum of utilities.\n\n" "$USER" "$DISTRO"

while true; do
    printf "\r\033[2K Press Enter to continue or Ctrl+C to cancel."
    read -n1 -s -r
    # check if Ctrl+C
    if (( $? != 0 )); then
        exit 1
    fi
    # check if Enter (empty input)
    if [[ -z "$REPLY" ]]; then
        break
    fi
done

"${UPDATE[@]}" >/dev/null 2>&1 || fatal " no internet connection detected. Exiting."
case "$DISTRO" in
    arch)
		#"${PM[@]}" pacman-contrib  >/dev/null 2>&1 # use pactree instead of expac
		"${PM[@]}" expac  >/dev/null 2>&1
	;;
	fedora)
		dnf rm -y -q gpgme #bug fix for akonadi-server
	;;
esac

# fix wayland on nvidia gpu
nvidia_fix=false
nvidia_warning() {
	    if lspci | grep -i nvidia >/dev/null; then
        printf "\n\n WARNING: NVIDIA GPU Detected. Checking for NVIDIA Wayland fix...\n\n"
		sleep 2
        if grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
			printf " Fix already present in GRUB config. Proceeding with KDE installation..."
			nvidia_fix=true
        else
            sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia-drm.modeset=1"/' /etc/default/grub
			printf " NVIDIA Wayland fix applied. You will need to reboot your system !\n Proceeding with KDE installation..."
            nvidia_fix=true
        fi
    fi
}

nvidia_warning

printf "\n\n Preparing KDE packages for %s...\n\n" "$DISTRO"

create_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    if dd if=/dev/zero of="$swap_file" bs=1M count=1024 status=none 2>/dev/null; then # create 1GB file
        chmod 600 "$swap_file"
        mkswap "$swap_file" >/dev/null 2>&1
        if swapon "$swap_file" -p 100 >/dev/null 2>&1; then # force the kernel to use swap file
            sysctl -w vm.swappiness=80 >/dev/null 2>&1 # force the system to use swap sooner
            return 0
        else
            echo "Failed to enable $swap_file." >&2
            return 1
        fi
    else
        echo "Cannot write to $swap_file" >&2
        return 1
    fi
}

remove_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    
    if [[ -f "$swap_file" ]]; then
        swapoff "$swap_file" >/dev/null 2>&1
        rm -f "$swap_file"
    fi
    sysctl -w vm.swappiness=60 >/dev/null 2>&1 # reset swappiness to default 60
}

init-term() {
    printf '\n' # ensure we have space for the scrollbar
    printf '\e7' # save the cursor location
    printf '\e[%d;%dr' 0 "$((LINES - 1))" # set the scrollable region (margin)
    printf '\e8' # restore the cursor location
    printf '\e[1A' # move cursor up
}

deinit-term() {
    printf '\e7' # save the cursor location
    printf '\e[%d;%dr' 0 "$LINES" # reset the scrollable region (margin)
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K' # clear the line
    printf '\e8' # reset the cursor location
}

progress-bar() {
    local current=$1 len=$2
    # avoid division by zero
    if (( len == 0 )); then
        fatal " ."
        exit 1
    fi
    # calculate percentage and string length
    local perc_done=$((current * 100 / len))
    local suffix=" ($perc_done%)"
    local length=$((COLUMNS - ${#suffix} - 4))
    local num_bars=$((perc_done * length / 100))

    # construct the bar string
    local i
    local s='['
    for ((i = 0; i < num_bars; i++)); do
        s+=$BAR_CHAR
    done
    for ((i = num_bars; i < length; i++)); do
        s+=$EMPTY_CHAR
    done
    s+=']'
    s+=$suffix

    printf '\e7' # save the cursor location
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K' # clear the line
    printf '%s' "$s" # print the progress bar
    printf '\e8' # restore the cursor location
}

recover_pacman() {
    rm -f /var/lib/pacman/db.lck >/dev/null 2>&1
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
}

recover_dpkg() {
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock  >/dev/null 2>&1
    dpkg --configure -a >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -f -y 2>/dev/null || true
}

recover_rpm() {
    rm -f /var/lib/rpm/.rpm.lock /var/lib/rpm/__db.* 2>/dev/null
    rpm --rebuilddb 2>/dev/null || true
    if [[ "$DISTRO" == "OpenSuse" ]]; then
        zypper verify --no-refresh 2>/dev/null || true
    fi
}

install_packages() {
    local pkg
    local ret=0
    local recover=""
    local LOG_DIR="/var/log/install-scripts"
    local TIMESTAMP=$(date +%Y%m%d)
    mkdir -p "$LOG_DIR"
    local SUCCESS_LOG="$LOG_DIR/$TIMESTAMP-install.log"
    local ERROR_LOG="$LOG_DIR/$TIMESTAMP-error.log"

    case "$DISTRO" in
        arch)            recover="recover_pacman" ;;
        debian)          recover="recover_dpkg" ;;
        fedora|opensuse) recover="recover_rpm" ;;
    esac

    for pkg in "$@"; do
        printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
        "${PM[@]}" "$pkg" >/dev/null 2>&1

        if [ $? -ne 0 ]; then
            $recover 2>&1 # recover install    
            #if [ ! -f "$ERROR_LOG" ]; then # append to error log
            echo "$TIMESTAMP-install failed: $pkg" >> "$ERROR_LOG"
        	"${PM[@]}" "$pkg" 2>&1 | tee -a "$ERROR_LOG" > /dev/null
            #fi
            printf '\r%-*s' "$COLUMNS" " -> Installation FAILED: $pkg"
            ret=1
        else
            #if [ ! -f "$SUCCESS_LOG" ]; then
                echo "$TIMESTAMP-install OK: $pkg" >> "$SUCCESS_LOG"
            #fi
        fi
    done

    return $ret
}

disable_dms() {
    case "$DISTRO" in
        arch|debian|fedora) # disable common display managers
            systemctl disable gdm gdm3 lightdm lxdm xdm &>/dev/null || true
            ;;
        opensuse) # use yast to set the DM to none
			if command -v yast2 >/dev/null 2>&1; then
            	yast2 displaymanager set default=none &>/dev/null || true
        	else
            	yast --modules 'System/DisplayManager' set_display_manager none &>/dev/null || true
			fi
            ;;
    esac
}

enable_wayland() {
	disable_dms
	case "$DISTRO" in
        arch|debian|fedora)
			systemctl enable sddm &>/dev/null || true
			;;
		opensuse)
			systemctl enable sddm.service -f &>/dev/null || true
			;;
	esac
}

upd_bootloader() {
    local cmd cfg
    if cmd=$(command -v update-grub 2>/dev/null); then
        "$cmd" >/dev/null
    elif cmd=$(command -v grub-mkconfig 2>/dev/null); then
        if cfg=$(grub2-editenv --boot-directory 2>/dev/null | cut -d= -f2); then
            cfg="$cfg/grub.cfg"
        else
            cfg="/boot/grub/grub.cfg"
            [[ -f /boot/grub2/grub.cfg ]] && cfg="/boot/grub2/grub.cfg"
        fi
			"$cmd" -o "$cfg" >/dev/null
    fi
}

end_install() {
    if [ "$nvidia_fix" = true ]; then
        upd_bootloader
    fi

    while true; do
        if [ "$nvidia_fix" = true ]; then
            printf "\r\033[2K Press (r) to reboot: "
        else
            printf "\r\033[2K Reboot (r) or start KDE now (k)? [r/k]: "
        fi
		read -n1 -s -r choice
        # check if Ctrl+C
        if (( $? != 0 )); then
            exit 1
        fi

        case "${choice,,}" in
            k) systemctl start sddm; break ;;
            r) printf "\n"; echo; (for ((i=5; i>0; i--)); do printf "\r Rebooting in %d...\033[0K" "$i"; sleep 1; done) && reboot; break ;;
            *) ;;
        esac
    done
}

main() {
    local OPTARG OPTIND opt
    while getopts 'b:c:e:s:h' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
			s) USE_SWAP=true ;;
			h) usage; exit 0 ;;
            \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
        esac
    done

    if [ "$USE_SWAP" = true ]; then
    	create_swap
	fi

    shopt -s globstar nullglob checkwinsize
    # ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    # build exact list of packages that will be installed
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        arch)
			# use pactree instead of expac >>>>>>>>
			# all_dep=$(pactree -l -s plasma-meta | sort -u && pactree -l -s dolphin | sort -u && pactree -l -s konsole | sort -u)
			# mapfile -t packages < <(
			# echo "$all_dep" | sort -u | comm -13 <(pacman -Qq) -
			# )
			# <<<<<<<<
            mapfile -t packages < <(
				expac -S '%D' "${pkg_names[@]}" | tr -s ' ' '\n' | sort -u | comm -13 <(pacman -Qq) - || true
            )
            ;;
        debian)
            # inherit the current locale for install
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            echo "locales locales/default_environment_locale select $current_locale" | debconf-set-selections
            echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8" | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" | awk '/^Inst / {print $2}'
            )
            ;;
        fedora)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '!/(^$|^=|---|^Package |^Arch |^Version |^Repository |^Size |After|Installing|Updating|Transaction|Operation|Repositories|Total|KDE)/ {print $1}' | sort -u
            )
            ;;
        opensuse)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' | grep -v "Mozilla" | grep -v "vlc" | grep -v "x11" | grep -v "xorg" | head -n -5                
            )
            ;;
    esac
	
	total=${#packages[@]}
    
	if (( total == 0 )); then
    	printf " Nothing to do – All packages are up to date.\n\n"
		enable_wayland
		end_install
	fi

    # array installation loop
    local current=0
    for ((i = 0; i < total; i += BATCHSIZE)); do
        install_packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        if (( current > total )); then # clamp current to total for the progress bar
            current=$total
        fi
        progress-bar "$current" "$total"
    done

	if [[ -f /var/tmp/ezkde_swap ]] then # remove swap if created
		if swapon -s | awk '$1=="/var/tmp/ezkde_swap" {print 1}' >/dev/null; then
			remove_swap
		fi
	fi
	
    enable_wayland
    printf "\n\n eZkde for %s installation successful.\n\n" "$DISTRO"
    end_install
    deinit-term
}

# run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
