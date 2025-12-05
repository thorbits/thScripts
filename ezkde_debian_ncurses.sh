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
    local width="${2:-78}"  # Default to 78 columns (80 - 2 for whiptail borders)
    local line padded
    local result=""

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

# Now downloading and installing:
install_minimal_kde() {
    local total=${#PKGS[@]} count=0

    {
        for pkg in "${PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            # First line: percentage (required)
            # Second part: updates the gauge text with package name
            printf "%d\nXXX\n%s (%d/%d)\nXXX\n" "$percent" "$pkg" "$count" "$total"
            apt-get install -y -qq "$pkg" >/dev/null 2>&1
            sleep 0.1
        done
        printf "100\n"
    } | whiptail --title "KDE Installation" --gauge "" 8 78 0
}

enable_and_start_sddm() {
    systemctl enable sddm >/dev/null 2>&1 || { echo -e "\e[31mFailed to enable SDDM\e[0m"; exit 1; }
    systemctl set-default graphical.target >/dev/null 2>&1
}

final_menu() {
    local menu_width=78
    local menu_height=$(( $(tput lines) - 5 ))  # Leave 5 lines for margins
    local menu_item_height=2

    choice=$(whiptail --title "eZkde for Debian" \
        --menu "$(center_text "KDE installation complete!
\nSelect what to do next:")" \
        "$menu_height" "$menu_width" "$menu_item_height" \
        "1" "Reboot now" \
        "2" "Start a KDE session now" \
        3>&1 1>&2 2>&3 || true)

    case "$choice" in
        1)
            sleep 0.5
            whiptail --title "eZkde for Debian" --msgbox "$(center_text "The system will reboot now...")" 8 78
            systemctl reboot
            ;;
        2)
            sleep 0.5
            whiptail --title "eZkde for Debian" --msgbox "$(center_text "Starting KDE session...")" 8 78
            systemctl isolate graphical.target
            ;;
    esac
}

main() {
    local silent=false

    # Parse command line arguments for silent mode
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --silent|-s)
                silent=true
                shift
                ;;
            *)
                shift
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
        local centered_intro=$(center_text "$intro_text")
        whiptail --title "eZkde for Debian" --msgbox "$centered_intro" 12 78 || true
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
