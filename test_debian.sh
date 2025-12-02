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
# Helper functions (log, ensure_whiptail, UI wrappers)
# ---------------------------------------------------------------------------
log() {
    local colour="${1:-32}"    # default = green
    shift
    printf "\e[${colour}m%s\e[0m\n" "$*"
}

ensure_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        log 33 "whiptail not found - installing it now..."
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
    kpipewire
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
            echo "$percent Installing $pkg..."
            apt-get install -y -qq --no-install-recommends "$pkg" \
                || { log 31 "Failed to install $pkg"; exit 1; }
            sleep 0.2   # smooth gauge movement (optional)
        done
        echo "100 Installation complete."
    } | ui_gauge "KDE Installation" "Installing minimal KDE packages..."
}

enable_and_start_sddm() {
    log 32 "Enabling and starting SDDM..."
    systemctl enable --now sddm >/dev/null 2>&1 \
        || { log 31 "Failed to enable/start SDDM"; exit 1; }
    log 32 "SDDM is now active."
}

# ---------------------------------------------------------------------------
# Main flow (no interactive menu any more)
# ---------------------------------------------------------------------------
main() {
    # Must be run as root
    if [[ "$(id -u)" -ne 0 ]]; then
        log 31 "This script must be run as root. Use sudo."
        exit 1
    fi

    ensure_whiptail

    # -----------------------------------------------------------------------
    # Intro – keep or comment out if you want a completely silent run
    # -----------------------------------------------------------------------
    ui_msgbox "KDE Installation" \
        "KDE 6 (Wayland session) will be installed with audio support (PipeWire) \
and a minimal set of utilities.\n\nPress OK to continue."

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
            log 32 "Rebooting now..."
            systemctl reboot
            ;;
        2)
            log 32 "Switching to graphical.target..."
            systemctl isolate graphical.target
            ;;
        *)
            log 33 "No valid selection made – leaving you at the shell."
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Run when the file is executed directly
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
