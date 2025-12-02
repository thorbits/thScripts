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
log() {
    local colour="${1:-32}"   # default = green
    shift
    printf "\e[${colour}m%s\e[0m\n" "$*"
}
# ---------------------------------------------------------------------------
ensure_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        log 33 "whiptail not found – installing it now…"
        apt-get update -qq
        apt-get install -y -qq whiptail
    fi
}
# ---------------------------------------------------------------------------
ui_msgbox()   { local t="$1" txt="$2"; whiptail --title "$t" --msgbox "$txt" 12 78; }
ui_yesno()    { local t="$1" txt="$2"; whiptail --title "$t" --yesno "$txt" 12 78; }
ui_menu()     { local t="$1" p="$2"; shift 2; whiptail --title "$t" --menu "$p" 20 60 10 "$@"; }
ui_gauge()    { local t="$1" txt="$2"; whiptail --title "$t" --gauge "$txt" 8 78 0; }

# ---------------------------------------------------------------------------
declare -a KDE_PKGS=(
    plasma-wayland-protocols kwin-wayland kpipewire sddm plasma-workspace
    plasma-nm plasma-discover kinfocenter systemsettings dolphin konsole
)

install_minimal_kde() {
    local total=${#KDE_PKGS[@]} count=0
    {
        for pkg in "${KDE_PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            echo "$percent Installing $pkg…"
            apt-get install -y -qq --no-install-recommends "$pkg" \
                || { log 31 "Failed to install $pkg"; exit 1; }
            sleep 0.2   # optional – makes the gauge look smoother
        done
        echo "100 Installation complete."
    } | ui_gauge "KDE Installation" "Installing minimal KDE packages…"
}

# ---------------------------------------------------------------------------
main_menu() {
    while true; do
        local menu_items=(
            1 "Install Minimal KDE Packages"
        )
        local choice
        choice=$(ui_menu "KDE Installation" "Choose an option:" "${menu_items[@]}" 3>&1 1>&2 2>&3) \
            || { log 33 "User pressed ESC – exiting."; exit 0; }

        case "$choice" in
            1) install_minimal_kde; break ;;
            *) log 33 "Invalid selection – exiting."; exit 1 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
main() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log 31 "This script must be run as root. Use sudo."
        exit 1
    fi
    ensure_whiptail

    ui_msgbox "KDE Installation" \
        "KDE 6 (Wayland session) will be installed with audio support (PipeWire) \
        and a minimal set of utilities.\n\nPress OK to continue."

    main_menu

    ui_msgbox "Success" "KDE has been installed. You may want to:\n\n• enable/start SDDM\n• reboot or start a Wayland session.\n\nEnjoy!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
