#!/bin/bash

# Must be run as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root. Use sudo.\e[0m"
    exit 1
fi

# Check if whiptail is installed (silent check)
if ! command -v whiptail &> /dev/null; then
    apt-get update && apt-get install -y whiptail || {
        echo -e "\e[31mFailed to install whiptail. Please install it manually.\e[0m"
        exit 1
    }
fi

# Welcome screen
if ! whiptail --title "Minimal KDE Wayland Installer" --yesno "This script will install a minimal KDE Plasma (Wayland) desktop environment.\n\nPackages to be installed:\n- plasma-wayland-protocols\n- kwin-wayland\n- pipewire\n- wireplumber\n- sddm\n- dolphin\n- konsole\n\nDo you want to continue?" 16 60; then
    echo -e "\e[33mInstallation cancelled by user.\e[0m"
    exit 0
fi

# Function to install packages with progress
install_kde_wayland() {
    # List of packages for minimal KDE Wayland
    PACKAGES=(
        plasma-wayland-protocols
        kwin-wayland
        pipewire
        wireplumber
        sddm
        dolphin
        konsole
    )

    # Update package lists
    {
        echo "XXX\n0\nUpdating package lists...\nXXX"
        apt-get update -qq
        echo "XXX\n10\nPackage lists updated.\nXXX"
    } | whiptail --title "Installing KDE Wayland" --gauge "Please wait while packages are being prepared..." 6 60 0

    # Install each package with progress
    TOTAL=${#PACKAGES[@]}
    COUNT=0
    for pkg in "${PACKAGES[@]}"; do
        COUNT=$((COUNT + 1))
        PERCENT=$((10 + (80 * COUNT / TOTAL)))

        {
            echo "XXX\n$PERCENT\nInstalling $pkg ($COUNT of $TOTAL)...\nXXX"
            apt-get install -y -qq "$pkg" || {
                echo "XXX\n100\n\e[31mError installing $pkg. Installation failed.\e[0m\nXXX"
                sleep 2
                exit 1
            }
        } | whiptail --title "Installing KDE Wayland" --gauge "Installing $pkg ($COUNT of $TOTAL)..." 6 60 "$PERCENT"
    done

    # Enable SDDM
    {
        echo "XXX\n90\nEnabling SDDM display manager...\nXXX"
        systemctl enable sddm
        echo "XXX\n100\nSDDM enabled.\nXXX"
    } | whiptail --title "Installing KDE Wayland" --gauge "Enabling SDDM..." 6 60 90
}

# Run the installation
install_kde_wayland

# Completion screen
if whiptail --title "Installation Complete" --yesno "KDE Plasma (Wayland) has been successfully installed.\n\nWould you like to reboot now or start a new KDE session?" 10 60 --yes-button "Reboot" --no-button "Start KDE"; then
    echo -e "\e[32mSystem will reboot now.\e[0m"
    reboot
else
    echo -e "\e[32mStarting KDE Wayland session...\e[0m"
    if [ -f /usr/bin/startplasma-wayland ]; then
        exec startplasma-wayland
    else
        echo -e "\e[33mCould not find startplasma-wayland. Please log out and select KDE Plasma (Wayland) from SDDM.\e[0m"
        whiptail --title "Session Start Failed" --msgbox "Could not find startplasma-wayland. Please log out and select KDE Plasma (Wayland) from your display manager." 8 60
    fi
fi
