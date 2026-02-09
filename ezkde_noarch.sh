#!/usr/bin/env bash

#   _______
#   |__ __|
#     ||horbits presents
#         _______
#	_____ |___  / __  __  _____   _____
# 	|  __|  /  /  | |/ / | ___ \ |  ___|
# 	|  _|  /  /__ | | \  | |_| | |  _| 
#	| |___/______||_|\_\ |_____/ | |___
#	|__________________________________|
#
#    eZkde for Arch / Debian / Fedora / OpenSuse
#    Automated KDE installation script
#    ---------------------------------------------------------#
#    Install the latest KDE 6.5.x / 6.6 beta (Wayland session)
#	 along with with PipeWire audio and a minimum of utilities.
#    ---------------------------------------------------------#

(return 0 2>/dev/null) && { echo " Error: This script must be executed, do not source." >&2; return 1; }
[ "$(id -u)" -eq 0 ] || { echo " Error: This script must be run as root (sudo)" >&2; exit 1; }

# global cleanup system
declare -A cleanup_items=()
cleanup_add() { cleanup_items["$1"]="$2"; }
run_cleanup() {
    for name in "${!cleanup_items[@]}"; do
        eval "${cleanup_items[$name]}" 2>/dev/null || true
    done
}
fatal() { printf '\n\n\e[31m [WARNING]\e[0m %s\n\n' "$*" >&2; exit 1; }
abort() { printf '\n\n\e[31m [WARNING]\e[0m process interrupted by: %s\n\n' "$USER" >&2; exit 130; }
trap abort INT TERM QUIT
trap run_cleanup EXIT
remove_swap() {
    local swap_file="/var/tmp/ezkde_swap"
    swapoff "$swap_file" >/dev/null 2>&1 || true
    rm -f "$swap_file"
    sysctl -qw vm.swappiness=60 >/dev/null 2>&1 || true
}
cleanup_add "swap" 'remove_swap'
create_swap() {
    local swap_file="/var/tmp/ezkde_swap"
	trap - ERR  # disable any ERR trap
    if ! dd if=/dev/zero of="$swap_file" bs=1M count=1024 status=none 2>/dev/null; then
        fatal "cannot write to $swap_file"
    fi
    chmod 600 "$swap_file" || { rm -f "$swap_file"; fatal "failed to set permissions"; }
    mkswap "$swap_file" >/dev/null 2>&1 || { rm -f "$swap_file"; fatal "failed to format"; }
    swapon "$swap_file" -p 100 >/dev/null 2>&1 || { rm -f "$swap_file"; fatal "failed to enable"; }
    sysctl -qw vm.swappiness=80 >/dev/null 2>&1 || true
}

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

# default tunables, see usage
BATCHSIZE=${BATCHSIZE:-1}
BAR_CHAR=${BAR_CHAR:-'|'}
EMPTY_CHAR=${EMPTY_CHAR:-' '}
USE_SWAP=false

os_release() {
    awk -F= '/^ID=/{gsub(/"/,""); print tolower($2)}' /etc/os-release | cut -d- -f1
}
DISTRO=$(os_release)

case "$DISTRO" in
    arch)
    	UPDATE=(pacman -Sy)
    	PM=(pacman -S --needed --noconfirm)
    	LIST_CMD=(pacman -Sp --print-format '%n')
	;;
    debian)
    	UPDATE=(apt-get update)
    	PM=(apt-get install -y -o Dpkg::Options::="--force-confdef")
    	LIST_CMD=(apt-get install --dry-run -qq)
	;;
    fedora)
    	UPDATE=(dnf up -yq)
    	PM=(dnf in -yq)
    	LIST_CMD=(dnf in -yq --assumeno)
	;;
    opensuse)
    	UPDATE=(zypper ref)
    	PM=(zypper in -y)
    	LIST_CMD=(zypper in -y -D --force-resolution)
	;;
    *)
		fatal " unsupported distribution: $DISTRO"
	;;
esac

declare -A KDE_GROUP # map each distro to its native KDE (meta) packages
KDE_GROUP[arch]="plasma-meta dolphin konsole"
KDE_GROUP[debian]="plasma-workspace dolphin konsole pipewire sddm"
KDE_GROUP[fedora]="@kde-desktop sddm"
KDE_GROUP[opensuse]="patterns-kde-kde_plasma konsole discover dolphin pipewire sddm"
#KDE_GROUP[fedora]="plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland dolphin discover"
#KDE_GROUP[opensuse]="discover6 sddm patterns-kde-kde_plasma" #plasma6-desktop dolphin sddm sddm-config-wayland

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

printf "\n\n #%s#\n\n" "$(printf '%*s' "$(( $(tput cols) - 4 ))" '' | tr ' ' '-')"
printf " Welcome %s, to eZkde for %s.\n\n The latest version of KDE 6.5.x (Wayland session) will be installed with audio support (Pipewire) SDDM and a minimum of utilities.\n\n" "$USER" "$DISTRO"

while true; do
    printf $'\r\033[2K Press Enter to continue or Ctrl+C to cancel'
    read -n1 -s -r
    (( $? != 0 )) && exit 1 # exit if Ctrl+C was pressed
    [[ -z "$REPLY" ]] && break # continue if Enter was pressed
done

"${UPDATE[@]}" >/dev/null 2>&1 || fatal "no internet connection detected."

# fix wayland on nvidia gpu
nvidia_fix=false
fix_nvidia_modeset() {
    local conf_file="/etc/modprobe.d/nvidia.conf"
    local required_line="options nvidia_drm modeset=1"
    # ensure the config directory exists
    mkdir -p "$(dirname "$conf_file")"
    # safely append only if not already present
    if ! grep -qxF "$required_line" "$conf_file" 2>/dev/null; then
        printf '%s\n' "$required_line" | tee -a "$conf_file"
    fi
    # update Initramfs - required for the change to work at boot
    case "$DISTRO" in
        arch)
            local mkinitconf="/etc/mkinitcpio.conf"
            if [[ -f "$mkinitconf" ]]; then
                # add nvidia and nvidia_drm only if missing
                for mod in nvidia nvidia_drm; do
                    if ! grep -qE "^MODULES=.*\b${mod}\b" "$mkinitconf" 2>/dev/null; then
                        sed -i "/^MODULES=/ s/)/ ${mod})/" "$mkinitconf"
                    fi
                done
            fi
            if command -v mkinitcpio >/dev/null 2>&1; then
                mkinitcpio -P >/dev/null
            fi
            ;;
        debian)
            if command -v update-initramfs >/dev/null 2>&1; then
                update-initramfs -u -k all >/dev/null
            fi
            ;;
        fedora|opensuse)
            if command -v dracut >/dev/null 2>&1; then
                dracut --regenerate-all --force >/dev/null
            fi
            ;;
    esac
}

nvidia_warning() {
    if lspci -nnk 2>/dev/null | grep -iA3 "VGA" | grep -iq "nvidia"; then
        printf " INFO: NVIDIA GPU detected, checking DRM modeset configuration..."
        local modeset_status="0"
        local conf_file="/etc/modprobe.d/nvidia.conf"
        # check live module (if loaded)
        if [[ -f /sys/module/nvidia_drm/parameters/modeset ]]; then
            modeset_status=$(cat /sys/module/nvidia_drm/parameters/modeset)
        # if not loaded, check config file robustly
        elif [[ -f "$conf_file" ]]; then
            # safer: is there a *non-commented* line containing `nvidia_drm ... modeset`?
            if grep -qE "^[^#]*nvidia_drm.*modeset=1" "$conf_file" 2>/dev/null; then
                modeset_status="Y"
            else
                modeset_status="0"
            fi
        fi
        # if modeset is not properly enabled (≠ "1" and ≠ "Y"), apply fix
        if [[ "$modeset_status" != "Y" && "$modeset_status" != "1" ]]; then
            fix_nvidia_modeset
            nvidia_fix=true
            printf " NVIDIA Wayland fix applied. You will need to reboot your system.\n Proceeding with KDE installation..."
        else
            printf " %s is already correct.\n Proceeding with KDE installation..." "$conf_file"
        fi
    fi
}

init-term() {
    printf '\n'		# ensure we have space for the scrollbar
    printf '\e7'	# save the cursor location
    printf '\e[%d;%dr' 0 "$((LINES - 1))" # set the scrollable region (margin)
    printf '\e8'	# restore the cursor location
    printf '\e[1A'	# move cursor up
}

deinit-term() {
    printf '\e7'		# save the cursor location
    printf '\e[%d;%dr' 0 "$LINES" # reset the scrollable region (margin)
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K'		# clear the line
    printf '\e8'		# reset the cursor location
}

progress-bar() {
    local current=$1 len=$2
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

    printf '\e7'		# save the cursor location
    printf '\e[%d;%dH' "$LINES" 0 # move cursor to the bottom line
    printf '\e[0K'		# clear the line
    printf '%s' "$s"	# print the progress bar
    printf '\e8'		# restore the cursor location
}

#recover_pacman() {
#    rm -f /var/lib/pacman/db.lck >/dev/null 2>&1
#    pacman -Sy --noconfirm >/dev/null 2>&1 || true
#}
#
#recover_dpkg() {
#    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock  >/dev/null 2>&1
#    dpkg --configure -a >/dev/null 2>&1
#    DEBIAN_FRONTEND=noninteractive apt-get install -f -y 2>/dev/null || true
#}
#
#recover_rpm() {
#    rm -f /var/lib/rpm/.rpm.lock /var/lib/rpm/__db.* 2>/dev/null
#    rpm --rebuilddb 2>/dev/null || true
#    if [[ "$DISTRO" == "OpenSuse" ]]; then
#        zypper verify --no-refresh 2>/dev/null || true
#    fi
#}

install_packages() {
    for pkg in "$@"; do
		printf '\r\033[K -> Now downloading and installing: %s' "$pkg"
#        printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
        "${PM[@]}" "$pkg" </dev/null >/dev/null 2>&1
		sleep .2
    done
}

manage_dm(){
    systemctl disable "$dm_unit" >/dev/null 2>&1
    systemctl enable sddm.service >/dev/null 2>&1
        if [[ $(systemctl get-default) == "multi-user.target" ]]; then
            systemctl set-default graphical.target >/dev/null 2>&1
        fi
}

enable_dm() {
local dm_unit
    case "$DISTRO" in
        arch|debian|fedora)
            dm_unit=$(systemctl show -p Id --value display-manager 2>/dev/null)
            ;;
        opensuse)
            dm_unit=$(systemctl list-unit-files --state=enabled | awk '$1 ~ /display-manager/ {print $1}')
            ;;
    esac
    if ! command -v sddm >/dev/null 2>&1; then
        fatal " sddm binary not found. Please install it first."
    fi
    # handle generic or legacy display managers
    if [[ "$dm_unit" == "display-manager.service" ]]; then
        systemctl enable sddm.service >/dev/null 2>&1
        if [[ $(systemctl get-default) == "multi-user.target" ]]; then
            systemctl set-default graphical.target >/dev/null 2>&1
        fi
    elif [[ "$dm_unit" == "display-manager-legacy.service" ]]; then
        manage_dm
    # handle specific display managers
    elif [[ -n "$dm_unit" ]]; then
        manage_dm
    fi
}

#upd_bootloader() {
#    local cmd cfg
#    if cmd=$(command -v update-grub 2>/dev/null); then # debian
#        "$cmd"
#    elif cmd=$(command -v grub-mkconfig 2>/dev/null) || cmd=$(command -v grub2-mkconfig 2>/dev/null); then # arch/fedora/opensuse
#        if [[ -d /boot/grub2 ]]; then
#            cfg="/boot/grub2/grub.cfg"
#        elif [[ -d /boot/grub ]]; then
#            cfg="/boot/grub/grub.cfg"
#        fi
#        "$cmd" -o "$cfg" >/dev/null 2>&1
#    elif cmd=$(command -v bootctl 2>/dev/null); then # systemd-boot (arch/EFI)
#        if [[ -d /boot/loader ]]; then
#            "$cmd" update >/dev/null 2>&1
#        fi
#    fi
#}

end_install() {
#    if [ "$nvidia_fix" = true ]; then
#        upd_bootloader
#    fi
    while true; do
        if [ "$nvidia_fix" = true ]; then
            printf "\r\033[2K Press (r) to reboot: "
        else
            printf "\r\033[2K Reboot (r) or start KDE now (k)? [r/k]: "
        fi
		read -n1 -s -r choice
		if (( $? != 0 )); then # check if Ctrl+C
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
#            \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 1 ;;
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
    printf "\n\n Preparing KDE packages for %s...\n\n" "$DISTRO"
	# # per package group, map all individual dependencies
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        arch)
            mapfile -t packages < <(
				"${LIST_CMD[@]}" "${pkg_names[@]}"
			)
			;;
        debian)
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            {
              echo "locales locales/default_environment_locale select $current_locale"
              echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8"
            } | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" | awk '/^Inst / {print $2}'
            )
            ;;
        fedora)
            mapfile -t packages < <(
				"${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 | grep "^ " | awk '{print $1}' | head -n -4 | sort -u
        	)
            ;;
        opensuse)
            mapfile -t packages < <(
				"${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
				awk '/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' | head -n -5 | grep -v "session-x11"
			)
#				zypper in -y -D patterns-kde-kde_plasma konsole dolphin pipewire sddm | head -n -18 | tail -n +9 | xargs -n 1
#				zypper se --requires kde konsole dolphin pipewire sddm | sed '/pattern$/d'
#               awk '/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' | grep -v "Mozilla" | grep -v "vlc" | grep -v "x11" | grep -v "xorg" | head -n -5 
            ;;
    esac
	total=${#packages[@]}
    if (( total == 0 )); then
		    if [ "$USE_SWAP" = true ]; then
				remove_swap
			fi
		printf " Nothing to do – All packages are up to date.\n\n"
		enable_dm
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
	if [ "$USE_SWAP" = true ]; then
		remove_swap
	fi
	printf '\r%-*s' "$COLUMNS" '' # clear the installation line
	enable_dm
    printf " eZkde for %s installation successful.\n\n" "$DISTRO"
	end_install
    deinit-term
}
# main sequence
nvidia_warning
main "$@"
