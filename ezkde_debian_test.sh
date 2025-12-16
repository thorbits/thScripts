#!/bin/bash

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
    exit 1
fi

# Check if whiptail is installed (with silent update)
apt-get update -qq
if ! command -v whiptail &> /dev/null; then
    apt-get install -y -qq whiptail || {
        exit 1
    }
fi

# Welcome screen
if ! whiptail --title "eZkde for Debian" --yesno "\nKDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\nDo you want to continue?" 16 78; then
    echo -e "\e[33mInstallation cancelled by user.\e[0m"
    exit 0
fi

# Main Function for installation
install_kde_wayland() {
    # List of packages for minimal KDE Wayland
    PACKAGES=(
        plasma-wayland-protocols
        kwin-wayland
        pipewire
        sddm
        dolphin
        konsole
    )
    
    TOTAL=${#PACKAGES[@]}
    COUNT=0
    
    # Start whiptail gauge ONCE with static title
    exec 3>&1
    whiptail --title "eZkde for Debian" --gauge "Starting installation..." 10 78 0 3>&1 1>&2 2>&3 &
    whiptail_pid=$!
    
    for pkg in "${PACKAGES[@]}"; do
        COUNT=$((COUNT + 1))
        PERCENT=$((10 + (80 * COUNT / TOTAL)))
        
        # Send ONLY percentage + dynamic message text (NOT a new whiptail command)
        echo "$PERCENT\nDownloading and installing $pkg ($COUNT of $TOTAL)..." >&3
        
        # Install quietly with error handling
        if ! apt-get install -y -qq "$pkg"; then
            echo "ERROR: Failed to install $pkg" >&2
            kill $whiptail_pid 2>/dev/null
            exit 1
        fi
    done
    
    # Close gauge cleanly with 100% only
    echo "100" >&3
    wait $whiptail_pid 2>/dev/null
    exec 3>&-
    
    # Enable SDDM and show completion dialog
    systemctl enable sddm.service >/dev/null 2>&1
    
    if whiptail --title "eZkde for Debian" --yesno \
        "KDE (Wayland) has been successfully installed.\n\n\
Would you like to reboot now or start a new KDE session?" \
        16 78 \
        --yes-button "Reboot" \
        --no-button "Start KDE"; then
        systemctl reboot
    else
        systemctl start sddm.service >/dev/null 2>&1
        systemctl isolate graphical.target
    fi
}
# Run the installation
install_kde_wayland
exit 0
