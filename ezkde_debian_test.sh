#!/bin/bash

# Check for root privileges
if [ "$(id -u)" != "0" ]; then
    whiptail --title "Error" --msgbox "This script must be run as root" 10 60
    exit 1
fi

# Check for whiptail dependency - auto-install if missing
if ! command -v whiptail >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq whiptail
fi

# Welcome screen
if ! whiptail --title "KDE Installation" --yesno "This script will install a minimal KDE Plasma Wayland setup. Continue?" 10 60; then
    exit 0
fi

# Get total packages to install (including your specified packages)
total_packages=$(apt-get install --simulate plasma-wayland-protocols kwin-wayland pipewire sddm dolphin konsole 2>/dev/null | grep 'Inst' | wc -l)
[ "$total_packages" -eq 0 ] && total_packages=1  # Avoid division by zero

# Start installation with progress gauge
current=0
apt-get install -y plasma-wayland-protocols kwin-wayland pipewire sddm dolphin konsole 2>&1 | while read -r line; do
    if [[ $line == *"Setting up"* ]]; then
        current=$((current + 1))
        percent=$((current * 100 / total_packages))
        echo "$percent"
    fi
done | whiptail --gauge "Installing KDE packages" 10 70 0

# Check installation success
if [ $? -ne 0 ]; then
    whiptail --title "Error" --msgbox "KDE installation failed. Check logs with 'journalctl -xe'" 10 60
    exit 1
fi

# Completion screen with options (only Reboot and Start Session)
choice=$(whiptail --title "Installation Complete" --menu "Choose an action:" 15 60 2 \
    "Reboot" "Restart system to apply changes" \
    "Start Session" "Start KDE session immediately" \
    3>&1 1>&2 2>&3)

case "$choice" in
    "Reboot")
        reboot
        ;;
    "Start Session")
        systemctl start sddm
        ;;
esac

exit 0
