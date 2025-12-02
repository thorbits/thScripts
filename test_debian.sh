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

# ---------------------------------------------------------------------------
# Helper functions (ensure_whiptail and UI wrappers)
# ---------------------------------------------------------------------------
ensure_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        echo -e "\e[33mwhiptail not found - installing it now...\e[0m"
        apt-get update -qq
        apt-get install -y -qq whiptail
    fi
}

ui_msgbox() { local t="$1" txt="$2"; whiptail --title "$t" --msgbox "$txt" 12 78; }
ui_yesno()  { local t="$1" txt="$2"; whiptail --title "$t" --yesno "$txt" 12 78; }
ui_menu()   { local t="$1" p="$2"; shift 2; whiptail --title "$t" --menu "$p" 15 60 2 "$@"; }
ui_gauge()  { local t="$1" txt="$2"; whiptail --title "$t" --gauge "$txt" 8 78 0; }

# ---------------------------------------------------------------------------
# Package list & installer
# ---------------------------------------------------------------------------
declare -a PKGS=(
    plasma-wayland-protocols
    kwin-wayland
    pipewire
    sddm
    dolphin
    konsole
)

install_minimal_kde() {
    local total=${#PKGS[@]} count=0
    {
        for pkg in "${PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            echo "$percent Installing $pkg..."
            apt-get install -y -qq --no-install-recommends "$pkg" \
                || { echo -e "\e[31mFailed to install $pkg\e[0m"; exit 1; }
            # Small pause makes the gauge move more smoothly (optional)
            sleep 0.2
        done
        echo "100 Installation complete."
    } | ui_gauge "KDE Installation" "Installing minimal KDE packages…" || true
}

enable_and_start_sddm() {
    echo -e "\e[32mEnabling and starting SDDM...\e[0m"
    systemctl enable --now sddm >/dev/null 2>&1 \
        || { echo -e "\e[31mFailed to enable/start SDDM\e[0m"; exit 1; }
    echo -e "\e[32mSDDM is now active.\e[0m"
}

# ---------------------------------------------------------------------------
# Main flow (no interactive menu any more)
# ---------------------------------------------------------------------------
main() {
    # Must be run as root
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
        exit 1
    fi

    ensure_whiptail

    # -----------------------------------------------------------------------
    # Intro – keep or comment out if you want a completely silent run
    # -----------------------------------------------------------------------
    ui_msgbox "KDE Installation" \
        "KDE 6 (Wayland session) will be installed with audio support (PipeWire) \
and a minimal set of utilities.\n\nPress OK to continue." || true

    # -----------------------------------------------------------------------
    # Install the packages
    # -----------------------------------------------------------------------
    install_minimal_kde

    # -----------------------------------------------------------------------
    # Enable and start SDDM
    # -----------------------------------------------------------------------
    enable_and_start_sddm

    # -----------------------------------------------------------------------
    # Final menu with clickable actions (plain ASCII only)
    # -----------------------------------------------------------------------
    choice=$(ui_menu "Installation Complete" \
        "Select what to do next:" \
        1 "Reboot now" \
        2 "Switch to graphical target now")

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

# ---------------------------------------------------------------------------
# Run when the file is executed directly
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
