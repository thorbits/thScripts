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
IFS=$'\n\t'   # sane field splitting

#  Print a coloured message to the terminal (used for debugging / logs)
log() {
    local colour="${1:-32}"   # default = green
    shift
    printf "\e[${colour}m%s\e[0m\n" "$*"
}

#  Dependency handling
ensure_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y -qq whiptail
    fi
}

#   UI helpers – all dialogs go through these wrappers so we keep the code tidy
ui_msgbox() {
    local title="$1" text="$2"
    whiptail --title "$title" --msgbox "$text" 12 78
}

ui_yesno() {
    local title="$1" text="$2"
    if whiptail --title "$title" --yesno "$text" 12 78; then
        return 0
    else
        return 1
    fi
}

ui_menu() {
    local title="$1" prompt="$2" shift=3
    # $@ will be the list of <tag> <item> pairs
    whiptail --title "$title" --menu "$prompt" 20 60 10 "$@"
}

ui_gauge() {
    local title="$1" text="$2"
    whiptail --title "$title" --gauge "$text" 8 78 0
}

#   Package installation logic
declare -a KDE_PKGS=(
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
    local total=${#KDE_PKGS[@]}
    local count=0

    # The gauge reads from its stdin. We build a subshell that prints
    # "<percentage> <message>" for each package.
    {
        for pkg in "${KDE_PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            # Print the progress line for whiptail
            echo "$percent Installing $pkg…"
            # Install the package (quiet, no recommends)
            apt-get install -y -qq --no-install-recommends "$pkg" \
                || { log 31 "Failed to install $pkg"; exit 1; }
            # Give a tiny pause so the gauge feels smoother (optional)
            sleep 0.2
        done
        # Final 100 % line – required to close the gauge cleanly
        echo "100 Installation complete."
    } | ui_gauge "KDE Installation" "Installing minimal KDE packages…"
}

#   Main menu loop
main_menu() {
    while true; do
        # Build the menu items as a flat list: tag description tag description …
        local menu_items=(
            1 "Install Minimal KDE Packages"
            2 "Cancel"
        )
        local choice
        choice=$(ui_menu "KDE Installation" "Choose an option:" "${menu_items[@]}" 3>&1 1>&2 2>&3) \
            || { log 33 "User pressed ESC – exiting."; exit 0; }

        case "$choice" in
            1) install_minimal_kde; break ;;   # after a successful install we exit the loop
            2) ui_msgbox "Cancelled" "KDE install canceled."; exit 0 ;;
            *) log 33 "Invalid selection – looping again."; ;;
        esac
    done
}

#   Script entry point
main() {
    # Must be run as root – give a clear error if not.
    if [[ "$(id -u)" -ne 0 ]]; then
        log 31 "This script must be run as root. Use sudo."
        exit 1
    fi

    ensure_whiptail

    #   Intro dialog – give the user a chance to abort before any network I/O
    ui_msgbox "KDE Installation" \
        "KDE 6 (Wayland session) will be installed with audio support (PipeWire) \
        and a minimal set of utilities.\n\nPress OK to continue."

    #   Run the interactive menu
    main_menu

    #   Final clean‑up / success message
    ui_msgbox "Success" "KDE has been installed. You may want to:\n\n• enable/start SDDM\n• reboot or start a Wayland session.\n\nEnjoy!"
}

# Execute only if the script is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
