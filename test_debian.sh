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

# ---------- package list & installer ----------
declare -a KDE_PKGS=( … )   # your list stays unchanged

install_minimal_kde() {
    local total=${#KDE_PKGS[@]} count=0
    {
        for pkg in "${KDE_PKGS[@]}"; do
            ((count++))
            percent=$(( count * 100 / total ))
            echo "$percent Installing $pkg…"
            apt-get install -y -qq --no-install-recommends "$pkg" \
                || { log 31 "Failed to install $pkg"; exit 1; }
            sleep 0.2      # optional – makes the gauge smoother
        done
        echo "100 Installation complete."
    } | ui_gauge "KDE Installation" "Installing minimal KDE packages…"
}

# ---------------------------------------------------------------------------
#  **REMOVE** the whole main_menu() function – it is no longer needed.
# ---------------------------------------------------------------------------

main() {
    if [[ "$(id -u)" -ne 0 ]]; then
        log 31 "This script must be run as root. Use sudo."
        exit 1
    fi
    ensure_whiptail

    # ---- optional: keep the intro, or comment it out if you want zero UI ----
    ui_msgbox "KDE Installation" \
        "KDE 6 (Wayland session) will be installed with audio support (PipeWire) \
        and a minimal set of utilities.\n\nPress OK to continue."

    # -----------------------------------------------------------------------
    #  **DIRECT CALL** – skip the menu and start the install immediately
    # -----------------------------------------------------------------------
    install_minimal_kde

    # -----------------------------------------------------------------------
    #  Final success message (you can keep or remove it)
    # -----------------------------------------------------------------------
    ui_msgbox "Success" "KDE has been installed. You may want to:\n\n• enable/start SDDM\n• reboot or start a Wayland session.\n\nEnjoy!"
}
# ---------------------------------------------------------------------------

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
