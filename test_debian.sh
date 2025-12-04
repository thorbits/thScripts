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
    if ! command -v whiptail >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq whiptail
    fi
}

center_text() {
    local raw="${1}"
    local width="${2:-$(tput cols)}"
    local line padded
    local result=""
    
    while IFS= read -r line; do
        # Calculate left padding
        local pad_len=$(( (width - ${#line}) / 2 ))
        if (( pad_len > 0 )); then
            printf -v padded "%*s%s" "$pad_len" "" "$line"
        else
            padded="$line"
        fi
        result+="$padded"$'\n'
    done <<< "$raw"
    
    echo -n "$result"
}

# Package list
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

install_minimal_kde() {
    local total=${#PKGS[@]} count=0
    {
        for pkg in "${PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            stdbuf -oL echo "$percent"
            stdbuf -oL echo "$(center_text "Installing $pkg" 78)"
            apt-get install -y -qq "$pkg" \
                || { echo -e "\e[31mFailed to install $pkg\e[0m"; exit 1; }
            sleep 0.2
        done
        echo "100"
    } | whiptail --title "KDE Installation" --gauge "" 8 78 0 || true
}

enable_and_start_sddm() {
    echo -e "\e[32mEnabling and starting SDDM...\e[0m"
    systemctl enable sddm >/dev/null 2>&1 || { echo -e "\e[31mFailed to enable SDDM\e[0m"; exit 1; }
    systemctl set-default graphical.target >/dev/null 2>&1
    echo -e "\e[32mSDDM is now active.\e[0m"
}

final_menu() {
    local menu_width=$(tput cols)
    local menu_height=$(( $(tput lines) - 5 ))  # Leave 5 lines for margins
    local menu_item_height=2

    choice=$(whiptail --title "Installation Complete" \
        --menu "$(center_text "Select what to do next:")" \
        "$menu_height" "$menu_width" "$menu_item_height" \
        "1" "Reboot now" \
        "2" "Start a KDE session now" \
        3>&1 1>&2 2>&3 || true)

    case "$choice" in
        1)
            systemctl reboot
            ;;
        2)
            systemctl isolate graphical.target
            ;;
    esac
}

main() {
    local silent=false

    # Check for --silent flag
    for arg in "$@"; do
        case "$arg" in
            --silent)
                silent=true
                ;;
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
        local centered_intro
        centered_intro=$(center_text "$intro_text")
        whiptail --title "KDE Installation" --msgbox "$centered_intro" 12 $(tput cols) || true
    fi

    # Execute installation and configuration
    install_minimal_kde
    enable_and_start_sddm

    # Show completion menu unless in silent mode
    if [[ "$silent" == false ]]; then
        final_menu
    fi
}

# Run when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
