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
    UPDATE=(apt-get update -qq)
    PRE_BREW=(export DEBIAN_FRONTEND=noninteractive)
    LIST_CMD=(apt-get install --dry-run -qq)
    SRV_ENABLE=(systemctl enable sddm.service)
    SRV_START=(systemctl start sddm.service)
    SRV_TARGET=(systemctl isolate graphical.target)

elif command -v pacman  &>/dev/null; then
    DISTRO=Arch
    PM=(pacman -S --needed --noconfirm)
    UPDATE="pacman -Sy >/dev/null 2>&1"
    # LIST_CMD=(pacman -Sp)
    SRV_ENABLE=(systemctl enable sddm)
    SRV_START=(systemctl start sddm)
    SRV_TARGET=(systemctl isolate graphical.target)

elif command -v dnf     &>/dev/null; then
    DISTRO=Fedora
    PM=(dnf install -y --setopt=install_weak_deps=False)
    UPDATE=(dnf makecache --quiet)
    LIST_CMD=(dnf install --assumeno --quiet)
    SRV_ENABLE=(systemctl enable sddm)
    SRV_START=(systemctl start sddm)
    SRV_TARGET=(systemctl isolate graphical.target)

elif command -v zypper &>/dev/null; then
    DISTRO=OpenSuse
    PM=(zypper install -y)
    UPDATE=(zypper --quiet ref)
    LIST_CMD=(zypper install -y --dry-run)
    SRV_ENABLE=(systemctl enable sddm)
    SRV_START=(systemctl start sddm)
    SRV_TARGET=(systemctl isolate graphical.target)

else
    fatal "No supported package manager found (apt-get, pacman, dnf, zypper)."
fi

# Map each distro to its native KDE/plasma group name
declare -A KDE_GROUP
KDE_GROUP[Debian]="plasma-workspace pipewire sddm dolphin konsole"
KDE_GROUP[Arch]="plasma-meta pipewire sddm dolphin konsole"
KDE_GROUP[Fedora]="@kde-desktop pipewire sddm dolphin konsole"
KDE_GROUP[OpenSuse]="patterns-kde-kde sddm dolphin konsole"

# intro (now $DISTRO and $UPDATE are set)
clear
printf '\n\n Welcome %s, to eZkde for %s.\n\n' "$USER" "$DISTRO"
printf ' KDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\n'
printf ' Press Enter to continue or Ctrl+C to cancel.\n'
read -rp '' && "${UPDATE[@]}" || {
    printf '\n Connection error! Exiting.\n\n'
    exit 1
}

progress-bar() {
    local current=$1 len=$2
    # avoid division by zero
    if (( len == 0 )); then
        printf '\r\e[K All KDE packages are already installed.\n\n'
        exit 1
    fi

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
    local pkg
    if [[ $DISTRO == arch ]]; then
        printf '1\n2\n2\ny\n' | pacman -S --needed ${KDE_GROUP[Arch]} >/dev/null
        return
    fi
    # everyone else keeps the old per-package loop
    for pkg in "$@"; do
        printf '\r -> Now downloading and installing: %-50s' "$pkg"
        "${PM[@]}" "$pkg" >/dev/null
    done
}

main() {
    local OPTARG OPTIND opt
    while getopts 'b:c:e:' opt; do
        case "$opt" in
            b) BATCHSIZE=$OPTARG;;
            c) BAR_CHAR=$OPTARG;;
            e) EMPTY_CHAR=$OPTARG;;
            *) fatal 'bad option';;
        esac
    done

    shopt -s globstar nullglob checkwinsize
    # this line is to ensure LINES and COLUMNS are set
    (:)

    trap deinit-term exit
    trap 'init-term; progress-bar "$current" "$total"' WINCH
    init-term

    case "$DISTRO" in
        Arch) printf ' \nPreparing KDE packages for %s...\n\n' "$DISTRO" ;;
        *)    printf ' Preparing KDE packages for %s...\n\n' "$DISTRO" ;;
    esac

    # Build exact list of packages that will be installed
    IFS=' ' read -r -a pkg_names <<< "${KDE_GROUP[$DISTRO]}"
    local packages=() total

    case "$DISTRO" in
        Debian)
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/^Inst / {print $2}'
            )
            total=${#packages[@]}
            # Pre-seed to inherit the user’s current locale 
            current_locale=${LC_ALL:-${LANG:-C.UTF-8}}
            current_locale=${current_locale%%.*}.UTF-8
            echo "locales locales/default_environment_locale select $current_locale" | debconf-set-selections
            echo "locales locales/locales_to_be_generated multiselect $current_locale UTF-8" | debconf-set-selections
            export DEBIAN_FRONTEND=noninteractive
            ;;
        Arch)
            mapfile -t packages < <(
                pacman -Sp --print-format '%n' "${pkg_names[@]}" 2>/dev/null |
                grep -v '^warning' || true
            )
            total=${#packages[@]}
            ;;
        Fedora|OpenSuse)
            # dnf/zypper dry-run still lists everything
            mapfile -t packages < <(
                "${LIST_CMD[@]}" "${pkg_names[@]}" 2>&1 |
                awk '/Installing.*:/ {print $2}' | sed 's/:$//' | sort -u
            )
            total=${#packages[@]}
            ;;
    esac

    (( total )) || { printf 'Nothing to do – KDE is already installed.\n'; exit 0; }

    # Batch installation loop
    local current=0
    for ((i = 0; i < total; i += BATCHSIZE)); do
        install_packages "${packages[@]:i:BATCHSIZE}"
        current=$((current + BATCHSIZE))
        progress-bar "$current" "$total"
    done
    progress-bar "$total" "$total"

    # Enable display manager
    "${SRV_ENABLE[@]}"
    printf '\r eZkde for %s installation complete!\n\n' "$DISTRO"
    read -rp $' Reboot (r) or start KDE now (k)? [r/k] ' choice
    case "${choice,,}" in
        k) "${SRV_START[@]}"; "${SRV_TARGET[@]}" ;;
        r) reboot ;;
    esac

    deinit-term
}

# Run only when executed, not sourced
[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
