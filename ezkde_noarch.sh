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

# must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    printf " This script must be run as root. Use sudo.\n"
    exit 1
fi

set -euo pipefail

# default tunables: ezkde_noarch [-b batchsize] [-c bar_char] [-e empty_char]
BATCHSIZE=${BATCHSIZE:-1}
BAR_CHAR=${BAR_CHAR:-'|'}
EMPTY_CHAR=${EMPTY_CHAR:-' '}

usage() {
	local prog=${0##*/}
	cat <<-EOF
	Usage: $prog [options]

	Tweak batch install size and progress bar appearance.

	Options
	  -b          batch size for packages, default is 1
	  -c          progress bar fill character, default is |
	  -e          progress bar empty character, default is ' '
EOF
}

fatal() {
    printf "[WARNING] %s\n" "$*" >&2
    exit 1
}

os_release() {
    echo "$(awk -F= '/^ID=/{print $2; exit}' /etc/os-release | tr -d '"')"
}

DISTRO=$(os_release)
if [ "$DISTRO" = "arch" ]; then
    UPDATE=(pacman -Sy)
    PM=(pacman -S --needed --noconfirm)
    LIST_CMD=(pacman -Sp --print-format '%n')

elif [ "$DISTRO" = "debian" ]; then
    UPDATE=(apt-get update)
    PM=(apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")
    LIST_CMD=(apt-get install --dry-run -qq)

elif command -v dnf &>/dev/null; then
    DISTRO=Fedora
    UPDATE=(dnf makecache)
    PM=(dnf install -y)
    LIST_CMD=(dnf install --assumeno)

elif command -v zypper &>/dev/null; then
    DISTRO=OpenSuse
    UPDATE=(zypper ref)
    PM=(zypper install -y)
    LIST_CMD=(zypper install -y --dry-run)

else
    fatal " no supported package manager found (apt-get, pacman, dnf, zypper). Exiting."
fi

# map each distro to its native KDE/plasma packages
declare -A KDE_GROUP
KDE_GROUP[Arch]="plasma-meta dolphin konsole"
KDE_GROUP[Debian]="plasma-workspace pipewire sddm dolphin konsole"
KDE_GROUP[Fedora]="@kde-desktop"
#KDE_GROUP[Fedora]="plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland dolphin"
KDE_GROUP[OpenSuse]="discover6 sddm patterns-kde-kde_plasma" #plasma6-desktop dolphin sddm sddm-config-wayland

# intro - DISTRO and UPDATE are set
clear
echo
case "$DISTRO" in
        Arch)
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
        Debian)
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
        Fedora)
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
        OpenSuse)
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

printf "\n\n Welcome %s, to eZkde for %s.\n\n" "$USER" "$DISTRO"

cat <<EOF
 #---------------------------------------------------#
 # The latest version of KDE 6.5.x (Wayland session) #
 #  will be installed with audio support (Pipewire), #
 #          SDDM and a minimum of utilities.         #
 #---------------------------------------------------#

EOF

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

# user pressed Enter, run the update.
"${UPDATE[@]}" >/dev/null 2>&1 || fatal " no internet connection detected. Exiting."
"${PM[@]}" expac  >/dev/null 2>&1

nvidia_warning() {
	nvidia_fix=false
    if lspci | grep -i nvidia >/dev/null; then
        printf "\n\n WARNING: NVIDIA GPU Detected. Checking for NVIDIA Wayland fix...\n\n"
		sleep 2
        if grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
			printf " Fix already present in GRUB config. Proceeding with KDE installation..."
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
    # create 1GB file
    if dd if=/dev/zero of="$swap_file" bs=1M count=1024 status=none 2>/dev/null; then
        chmod 600 "$swap_file"
        mkswap "$swap_file" >/dev/null 2>&1
        # force the kernel to use swap file
        if swapon "$swap_file" -p 100 >/dev/null 2>&1; then
            # swappiness 80 force the system to use swap sooner
            sysctl -w vm.swappiness=80 >/dev/null 2>&1
            return 0
        else
            rm -f "$swap_file"
        fi
    fi
}

remove_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    
    if [[ -f "$swap_file" ]]; then
        swapoff "$swap_file" >/dev/null 2>&1
        rm -f "$swap_file"
    fi
    # reset swappiness to default
    sysctl -w vm.swappiness=60 >/dev/null 2>&1
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
    rm -f /var/lib/pacman/db.lck >/dev/null
    pacman -Sy --noconfirm >/dev/null 2>&1 || true
}

recover_dpkg() {
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock  >/dev/null
    dpkg --configure -a >/dev/null
    DEBIAN_FRONTEND=noninteractive apt-get install -f -y
}

recover_rpm() {
    rm -f /var/lib/rpm/.rpm.lock /var/lib/rpm/__db.* >/dev/null
    rpm --rebuilddb >/dev/null 2>&1
    if [[ "$DISTRO" == "OpenSuse" ]]; then
        zypper verify --no-refresh >/dev/null 2>&1 || true
    fi
}

install_packages() {
    local pkg
    local ret=0
    local recover=""

    case "$DISTRO" in
        Arch)            recover="recover_pacman" ;;
        Debian)          recover="recover_dpkg" ;;
        Fedora|OpenSuse) recover="recover_rpm" ;;
    esac
    
    for pkg in "$@"; do
        printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
        "${PM[@]}" "$pkg" >/dev/null
    done
}

enable_wayland() {
	if systemctl is-enabled display-manager.service &>/dev/null; then
		systemctl disable display-manager.service &>/dev/null
    fi
	case "$DISTRO" in
        Arch|Debian)
			systemctl enable sddm &>/dev/null
			;;
		Fedora|OpenSuse)
    		local sddm_file="/etc/sddm.conf.d/sddm.conf"
    		if [ ! -f "$sddm_file" ]; then
        	touch "$sddm_file"
    		fi

    		if grep -q "DisplayServer=wayland" "$sddm_file"; then
        	:
    		else
        		if ! grep -q "^\[General\]" "$sddm_file"; then
             		printf "[General]\n" | tee -a "$sddm_file" >/dev/null
        		fi
        		if grep -q "^SDisplayServer=" "$sddm_file"; then
             	sed -i 's/^DisplayServer=.*/DisplayServer=wayland/' "$sddm_file"
         		else
             		printf "DisplayServer=wayland\n" | tee -a "$sddm_file" >/dev/null
         		fi
    		fi
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
    while getopts 'b:c:e:' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
            *) 
                echo >&2;
                usage >&2;
                exit 1
                ;;
        esac
    done

    #create_swap

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
        Arch)
            mapfile -t packages < <(
                #"${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                #grep -v '^warning' || true
				expac -S '%D' "${pkg_names[@]}" 2>&1 | tr -s ' ' '\n' | sort -u || true
            )
            total=${#packages[@]}
            ;;
        Debian)
            # inherit the current locale for install
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            echo "locales locales/default_environment_locale select $current_locale" | debconf-set-selections
            echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8" | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/^Inst / {print $2}'
            )
            total=${#packages[@]}
            ;;
        Fedora)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '!/(^$|^=|---|Dependencies resolved|Transaction Summary|Running transaction|Total download size|^Package |^Arch |^Version |^Repository |^Size |Installing|Updating|Repositories|Total|Operation|Nothing|After|KDE)/ {print $1}'
            )
            total=${#packages[@]}
            ;;
        OpenSuse)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' | grep -v "Mozilla" | grep -v "vlc" | grep -v "x11" | grep -v "xorg" | head -n -5                
            )
            total=${#packages[@]}
            ;;
    esac
    
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
        # clamp current to total for the progress bar
        if (( current > total )); then
            current=$total
        fi
        progress-bar "$current" "$total"
    done

    #remove_swap
    enable_wayland
    printf "\n\n eZkde for %s installation successful.\n\n" "$DISTRO"
    end_install
    deinit-term
}

# run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
