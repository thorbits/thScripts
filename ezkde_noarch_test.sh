#!/usr/bin/env bash
#
#	_______
#	\_   _/
#	  |_|horbits 
#
#	eZkde for Arch / Debian / Fedora / OpenSuse
#	Automated KDE installation script
# ------------------------------------------------------------
# Installs latest KDE 6.5.x (Wayland only) with audio support
# (PipeWire) and a minimum of utilities.
# ------------------------------------------------------------

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    printf " This script must be run as root. Use sudo.\n"
    exit 1
fi

set -euo pipefail

# Default tunables
BATCHSIZE=${BATCHSIZE:-1}
BAR_CHAR=${BAR_CHAR:-'|'}
EMPTY_CHAR=${EMPTY_CHAR:-' '}

fatal() {
    printf '[FATAL] %s\n' "$*" >&2
    exit 1
}

if   command -v apt-get  &>/dev/null; then
    DISTRO=Debian
    PM=(apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")
    UPDATE="apt-get update -qq"
    LIST_CMD=(apt-get install --dry-run -qq)
    SRV_START="systemctl start sddm.service >/dev/null 2>&1"
    SRV_TARGET="systemctl isolate graphical.target >/dev/null 2>&1"

elif command -v pacman  &>/dev/null; then
    DISTRO=Arch
    PM=(pacman -S --needed --noconfirm)
    UPDATE="pacman -Sy >/dev/null 2>&1"
    LIST_CMD=(pacman -Sp --print-format '%n')
    SRV_START="systemctl start sddm.service >/dev/null 2>&1"
    SRV_TARGET="systemctl isolate graphical.target >/dev/null 2>&1"

elif command -v dnf     &>/dev/null; then
    DISTRO=Fedora
    # PM=(dnf install -y --setopt=install_weak_deps=False)
    PM=(dnf install -y)
    UPDATE="dnf makecache >/dev/null 2>&1"
    LIST_CMD=(dnf install --assumeno)
    SRV_START="systemctl start sddm.service >/dev/null 2>&1"
    SRV_TARGET="systemctl isolate graphical.target >/dev/null 2>&1"

elif command -v zypper &>/dev/null; then
    DISTRO=OpenSuse
    PM=(zypper install -y)
    UPDATE="zypper --quiet ref"
    LIST_CMD=(zypper install -y --dry-run)
    SRV_START="systemctl start sddm.service >/dev/null 2>&1"
    SRV_TARGET="systemctl isolate graphical.target >/dev/null 2>&1"

else
    fatal "No supported package manager found (apt-get, pacman, dnf, zypper)."
fi

# Map each distro to its native KDE/plasma group name
declare -A KDE_GROUP
KDE_GROUP[Debian]="plasma-workspace pipewire sddm dolphin konsole"
KDE_GROUP[Arch]="plasma-meta dolphin konsole"
KDE_GROUP[Fedora]="dolphin plasma-desktop plasma-settings plasma-nm sddm-wayland-plasma kde-baseapps konsole kscreen sddm startplasma-wayland"
#KDE_GROUP[OpenSuse]="patterns-kde-kde"
KDE_GROUP[OpenSuse]="plasma6-desktop discover dolphin"

# intro (now $DISTRO and $UPDATE are set)
clear
printf '\n\n Welcome %s, to eZkde for %s.\n\n' "$USER" "$DISTRO"
printf ' KDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\n'
printf ' Press Enter to continue or Ctrl+C to cancel.\n'
read -rp '' && eval "$UPDATE" || {
    printf '\n ERROR: no internet connection detected. Exiting.\n\n'
    exit 1
}

progress-bar() {
    local current=$1 len=$2
    # avoid division by zero
    #if (( len == 0 )); then
    #    printf '\r\e[K All KDE packages are already installed.\n\n'
    #    exit 1
    #fi

    # Calculate percentage and string length
    local perc_done=$((current * 100 / len))
    local suffix=" ($perc_done%)"
    local length=$((COLUMNS - ${#suffix} - 4))
    local num_bars=$((perc_done * length / 100))

    # Construct the bar string
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

install_packages() {
    #if [[ "$DISTRO" == "Fedora" ]]; then
    #    printf '\r\e[2K -> Installing batch of %d packages...' "$#"
    #    printf "y" | dnf install -y @kde-desktop-environment --exclude=*. >/dev/null
    #else
        local pkg
        for pkg in "$@"; do
            printf '\r%-*s' "$COLUMNS" " -> Now downloading and installing: $pkg"
            "${PM[@]}" "$pkg" >/dev/null
        done
    #fi
}

main() {
    local OPTARG OPTIND opt
    while getopts 'b:c:e:' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
            *) fatal 'Usage: ezkde_noarch [-b batchsize] [-c bar_char] [-e empty_char]';;
        esac
    done

    shopt -s globstar nullglob checkwinsize
    # this line is to ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    printf ' Preparing KDE packages for %s...\n\n' "$DISTRO"
    
    # Build exact list of packages that will be installed
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        Debian)
            # Pre-seed to inherit the user’s current locale 
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
        Arch)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                grep -v '^warning' || true
            )
            total=${#packages[@]}
            ;;
        Fedora)
            mapfile -t packages < <(
                #printf "%s\n" "$(dnf install --assumeno "${pkg_names[@]}" 2>/dev/null | tail -2 | grep -o '[0-9]\+' | head -1)"
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk 'NF>=5 && $1 != "Package" {printf $1}' | head -n -3 | wc -l
            )
            total=${#packages[@]}
            ;;
        OpenSuse)
           mapfile -t packages > /tmp/mapfile_temp < <( 
            #mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/installed:/,/new/ {for(i=1;i<=NF;i++) if ($i ~ /^[a-zA-Z0-9.-]+$/) print $i}' |
                head -n -5
                #awk '/installed:/ {print $3; exit}'
                #awk '{print $3}' | sort -u | wc -l
                #awk '/Installing.*:/ {print $2}' | sed 's/:$//' | sort -u
                #awk '/^Installing/ {print $2}' | sort -u
                #grep -oE '^Installing[[:space:]]+[^[:space:]]+' | cut -d' ' -f2
                #grep -oE '[0-9]+' | tail -n 1
            )
            #total=${#packages[@]}
            total=$(wc -l < "/tmp/mapfile_temp")
            ;;
    esac
    
    (( total )) || { printf ' Nothing to do – KDE is already installed.\n\n'; exit 0; }

    # Batch installation loop
    local current=0
    for ((i = 0; i < total; i += BATCHSIZE)); do
        install_packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        progress-bar "$current" "$total"
    done
    progress-bar "$total" "$total"

    # Enable display manager
    systemctl enable sddm.service >/dev/null 2>&1

    # For Fedora, also enable pipewire audio
    if [[ "$DISTRO" == "Fedora" ]]; then
        systemctl --user --global enable pipewire pipewire-pulse >/dev/null 2>&1 || true
    fi
    
    printf '\n\n eZkde for %s installation complete!\n\n' "$DISTRO"
    read -rp $' Reboot (r) or start KDE now (k)? [r/k] ' choice
    case "${choice,,}" in
        k) eval "${SRV_START[@]}"; eval "${SRV_TARGET[@]}" ;;
        r) reboot ;;
    esac

    deinit-term
}

# Run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
