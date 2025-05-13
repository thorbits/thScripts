#!/bin/bash
#
#	_______
#	\_   _/
#	  |_|horbits 
#
#	eZkde for Debian

clear

printf "\n\nWelcome %s, to eZkde for Debian.\n\n" "$(whoami)"
printf "KDE 6 desktop (Wayland) will be installed with audio support (Pipewire) and minimum utilities.\n\nPress Enter to start.\n"
read
printf 'Installing components, this may take a while...\n\n'

# Use GNU time to measure the total duration of package installations
/usr/bin/time -p bash << 'EOF'
apt-get update -qq

pkgs="wayland-protocols kwin-wayland pipewire pipewire-pulse wireplumber sddm plasma-desktop plasma-nm plasma-discover kinfocenter systemsettings dolphin kitty"
total=$(echo $pkgs | wc -w)
count=0
max_len=0

for p in $pkgs; do 
  len=${#p}; 
  (( len > max_len )) && max_len=$len; 
done

format_str="\rProgress: %3d%% [%-20s] Now installing: %-${max_len}s"

for p in $pkgs; do 
  if ! dpkg -l | grep -q "^ii $p$"; then 
    count=$((count + 1))
    percent=$((count * 100 / total))
    unit=$((percent / 5))
    bar=$(printf '#%.0s' $(seq 1 $unit))
    printf "$format_str" "$percent" "$bar" "$p"
    
    apt-get install -y --no-install-recommends "$p" > /dev/null 2>&1
  fi;
done

printf "\rProgress: %3d%% [%-20s] Installed %d packages.\n" 100 "#" "$count"

EOF

systemctl enable sddm >/dev/null 2>&1

reboot_system() {
  echo -e "\n\neZkde for Debian install complete, system will reboot now.\n\nPress Enter to continue or Ctrl+C to cancel"
  read -rp '' && { 
    echo "GRUB_TIMEOUT=1" >> /etc/default/grub || sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    update-grub >/dev/null 2>&1 
  } && reboot
}

reboot_system
