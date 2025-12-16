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
if ! whiptail --title "eZkde for Debian" --yesno "\nKDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\nDo you want to continue?" 16 60; then
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

    # Install each package with progress
    TOTAL=${#PACKAGES[@]}
    COUNT=0
    for pkg in "${PACKAGES[@]}"; do
        COUNT=$((COUNT + 1))
        PERCENT=$((10 + (80 * COUNT / TOTAL)))

{
    echo "$PERCENT"
    apt-get install -y -qq "$pkg" || {
        echo "XXX\n100\n\e[31mError installing $pkg. Installation failed.\e[0m\nXXX"
        sleep 0.5
        exit 1
    }
} | whiptail --title "eZkde for Debian" --gauge "Downloading and installing $pkg ($COUNT of $TOTAL)..." 6 60 "$PERCENT"
    done

    # Enable SDDM to start on boot
    systemctl enable sddm.service >/dev/null 2>&1
    
    # Completion screen
    if whiptail --title "eZkde for Debian" --yesno "KDE (Wayland) has been successfully installed.\n\nWould you like to reboot now or start a new KDE session?" 10 60 --yes-button "Reboot" --no-button "Start KDE"; then
        systemctl reboot
    else
        # Start SDDM and switch to graphical session immediately
        systemctl start sddm.service >/dev/null 2>&1
        systemctl isolate graphical.target
    fi
}

# Run the installation
install_kde_wayland
exit 0
