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

# Helper functions
ensure_whiptail() {
    command -v whiptail >/dev/null 2>&1 || {
        apt-get update -qq
        apt-get install -y -qq whiptail
    }
}

center_text() {
    local text="$1"
    local width=78
    local length=${#text}
    local padding=$(( (width - length) / 2 ))
    printf "%${padding}s%s" "" "$text"
}

install_minimal_kde() {
    apt-get update
    apt-get install -y kde-plasma-desktop pipewire wireplumber sddm
}

enable_and_start_sddm() {
    systemctl enable sddm
    systemctl start sddm
}

final_menu() {
    choice=$(whiptail --title "eZkde for Debian" --menu "Choose an option" 15 60 4 \
        "1" "Reboot system" \
        "2" "Start KDE session" \
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

# Main function
main() {
    local silent=false
    # Parse command-line arguments for silent mode [1]
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
        intro_text="This script will install a minimal KDE Plasma Wayland setup.
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

# Entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
