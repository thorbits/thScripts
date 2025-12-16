#!/bin/bash
#
#	_______
#	\_   _/
#	  |_|horbits 
#
#	eZkde for Debian
#	Automated KDE installation script
# ------------------------------------------------------------
# Installs latest KDE 6.5.x (Wayland only) with audio support
# (PipeWire) and a minimum of utilities.
# ------------------------------------------------------------

clear

printf "\n\nWelcome %s, to eZkde for Debian.\n\n" "$USER"

printf "KDE 6.5.x (Wayland only) will be installed with audio support (Pipewire) and a minimum of utilities.\n\n"
printf "Press Enter to continue or Ctrl+C to cancel.\n"

read -rp '' && printf "Downloading and installing components, this may take a while...\n\n"

# Update package lists – quiet mode
apt-get update -qq ||
{
    printf "\nConnection error! Exiting.\n\n"
    exit 1
}

# Packages to be installed
pkgs=(
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

sum=${#pkgs[@]}
pkg_len=0

# Determine longest package name (for progress alignment)
for q in "${pkgs[@]}"; do
    ((${#q}>pkg_len)) && pkg_len=${#q}
done

i=0
ok=0

# Install each package, showing a progress bar
for p in "${pkgs[@]}"; do
    ((i++))

    dpkg -s "$p" &>/dev/null ||
    {
        apt-get install -y "$p" &>/dev/null && ((ok++))
    }

    printf "\rProgress: %3d%% [%-40s] %-*s" \
        $((i*100/sum)) \
        "$(printf '|%.0s' $(seq 1 $((i*40/sum))))" \
        "$pkg_len" "$p"
done

printf "\rProgress: 100%% [%-40s] Installed %d new component(s).\n\n" \
    "$(printf '|%.0s' $(seq 1 40))" "$ok"

# Enable SDDM display manager
systemctl enable sddm >/dev/null 2>&1

# Reboot helper – adjusts GRUB timeout, updates GRUB and reboots
reboot_system()
{
    printf "eZkde for Debian install complete, system will reboot now.\n\n"
    printf "Press Enter to continue or Ctrl+C to cancel"
    read -rp ''

    {
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub ||
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    } && update-grub >/dev/null 2>&1 && reboot
}

reboot_system ||
{
    printf "\neZkde for Debian installation error! Exiting.\n\n"
    exit 1
}
