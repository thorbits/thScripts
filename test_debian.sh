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

# Helper functions (ensure_whiptail, centering)
ensure_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo -e "\e[33mwhiptail not found - installing it now...\e[0m"
        apt-get update -qq
        apt-get install -y -qq whiptail
    fi
}

# Pad each line with spaces so it appears centered in a box of $width columns.
# Arguments:
#   $1 – the raw text (may contain new‑lines)
#   $2 – width of the box (default 78, must be an integer)
center_text() {
    local raw="${1}"
    local width="${2:-$(tput cols)}"  # Use terminal width if $2 is unset
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

# Package list & installer
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
    local gauge_width=$(tput cols)  # Dynamic width
    {
        for pkg in "${PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            stdbuf -oL echo "$percent"  # Unbuffered percentage
            stdbuf -oL echo "Installing $pkg..."
            apt-get install -y -qq "$pkg" \
                || { echo -e "\e[31mFailed to install $pkg\e[0m"; exit 1; }
            sleep 0.2
        done
        echo "100"
    } | whiptail --title "KDE Installation" --gauge "Downloading and installing components..." 8 "$gauge_width" 0 || true
}

enable_and_start_sddm() {
    echo -e "\e[32mEnabling and starting SDDM...\e[0m"
    systemctl enable sddm >/dev/null 2>&1 \
        || { echo -e "\e[31mFailed to enable/start SDDM\e[0m"; exit 1; }
    echo -e "\e[32mSDDM is now active.\e[0m"
}

# Main flow
main() {
    # Must be run as root
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
        exit 1
    fi

    ensure_whiptail

# Intro – keep or comment out if you want a completely silent run
    intro_text="KDE 6 (Wayland session) will be installed with audio support (PipeWire)
and a minimal set of utilities.

Press OK to continue."
    centered_intro=$(center_text "$intro_text" 78)
    # Ignore ESC/Cancel so the script continues even if the user aborts the box
    whiptail --title "KDE Installation" --msgbox "$centered_intro" 12 78 || true

    install_minimal_kde

    enable_and_start_sddm

# Final menu with clickable actions (plain ASCII only)
    choice=$(whiptail --title "Installation Complete" \
        --menu "Select what to do next:" 15 60 2 \
        1 "Reboot now" \
        2 "Switch to graphical target now" \
        3>&1 1>&2 2>&3)   # capture the selected tag

    case "$choice" in
        1)
            echo -e "\e[32mRebooting now...\e[0m"
            systemctl reboot
            ;;
        2)
            echo -e "\e[32mSwitching to graphical.target...\e[0m"
            systemctl isolate graphical.target
            ;;
        *)
            echo -e "\e[33mNo valid selection made – leaving you at the shell.\e[0m"
            ;;
    esac
}

# Run when the file is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
