#!/bin/bash
#
#    _______
#    \_   _/
#      |_|horbits 
#
#    eZkde for Debian
#    KDE‑6 (Wayland) minimal installer with audio (PipeWire) and a ncurses UI.
# -------------------------------------------------------------------------
#    Requirements:
#   - The script must be run as root (or via sudo).
#   - internet connection.
#   - Debian/Ubuntu‑based system (apt).
# -------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# -------------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------------
ensure_whiptail() {
    command -v whiptail >/dev/null 2>&1 || {
        apt-get update -qq
        apt-get install -y -qq whiptail
    }
}

center_text() {
    local raw="${1}"
    local width="${2:-78}"
    local line padded result=""
    while IFS= read -r line; do
        if (( ${#line} < width )); then
            local pad=$(( (width - ${#line}) / 2 ))
            padded="$(printf "%*s%s" "$pad" "" "$line")"
        else
            padded="$line"
        fi
        result+="${padded}"$'\n'
    done <<< "$raw"
    printf "%s" "${result%$'\n'}"
}

# -------------------------------------------------------------------------
# Package list
# -------------------------------------------------------------------------
declare -a PKGS=(
    plasma-wayland-protocols
    kwin-wayland
    pipewire
    sddm
    plasma-workspace
    plasma-nm
    plasma-discover
    kinfocenter
    systemsettings
    dolphin
    konsole
)

# -------------------------------------------------------------------------
# Installation gauge
# -------------------------------------------------------------------------
install_minimal_kde() {
    local total=${#PKGS[@]} i=0
    {
        for pkg in "${PKGS[@]}"; do
            ((i++))
            printf "%d\nXXX\n%s (%d/%d)\nXXX\n" $((i*100/total)) "$pkg" $i $total
            apt-get install -y -qq "$pkg" &>/dev/null
        done
        echo 100
    } | whiptail --gauge "Now downloading and installing…" 8 70 0
}

# -------------------------------------------------------------------------
# Enable and start SDDM
# -------------------------------------------------------------------------
enable_and_start_sddm() {
    systemctl enable sddm.service
    systemctl start sddm.service
}

# -------------------------------------------------------------------------
# Final menu - will be shown if script not silent
# -------------------------------------------------------------------------
final_menu() {
    local choice
    choice=$(whiptail --title "eZkde for Debian" \
        --menu "$(center_text "KDE installation complete!\n\nSelect what to do next:")" \
        15 60 4 \
        "1" "Reboot now" \
        "2" "Start KDE session now" \
        3>&1 1>&2 2>&3)

    case "$choice" in
        1)
            sleep 0.5
            whiptail --title "eZkde for Debian" \
                --msgbox "$(center_text "The system will reboot now...")" 8 78
            systemctl reboot
            ;;
        2)
            sleep 0.5
            whiptail --title "eZkde for Debian" \
                --msgbox "$(center_text "Starting KDE session...")" 8 78
            systemctl isolate graphical.target
            ;;
    esac
}

# -------------------------------------------------------------------------
# Main – parses --silent, shows menu only if not silent, runs installer 
# -------------------------------------------------------------------------
main() {
    local silent=false

    # Parse command‑line arguments for silent mode
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --silent|-s) silent=true; shift ;;
            *) shift ;;
        esac
    done

    # Must be run as root
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
        exit 1
    fi

    ensure_whiptail

    # Show introduction dialog unless in silent mode
    if [[ "$silent" == false ]]; then
        intro_text="KDE 6 (Wayland session) will be installed with audio support (PipeWire)
and a minimal set of utilities.

Press OK to continue."
        local centered_intro=$(center_text "$intro_text")
        whiptail --title "eZkde for Debian" --msgbox "$centered_intro" 12 78 || true
    fi

    # Run the installer, enable SDDM, then (if interactive) show menu
    install_minimal_kde
    enable_and_start_sddm
    if [[ "$silent" == false ]]; then
        final_menu
    fi
}

# -------------------------------------------------------------------------
# Entry point
# -------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
