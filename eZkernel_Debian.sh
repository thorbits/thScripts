#!/bin/bash

# Clear screen and welcome message
clear
printf "\n\nWelcome %s, to eZkernel for Debian.\n\nThe latest linux kernel from git.kernel.org will be compiled and installed.\n\n" "$(whoami)"

# Define steps and step function for progress indication
steps=3
step() {
  percent=$(( ($1 + 1) * 100 / steps ))
  printf "\rChecking kernels versions... (%d%%)" "$percent"
}

# Update package list and check connection
step 0
apt-get update -qq || { echo -e "\n\nConnection error. Exiting.\n"; exit 1; }
step 1

# Install required tools quietly
apt-get install -y curl > /dev/null 2>&1
step 2

# Fetch the latest kernel version
kver=$(curl -s https://www.kernel.org/ | grep -oP '(?<=<strong>)[^<]+(?=</strong>)' | head -n 2 | tail -n 1)

# Display current and new kernel versions, prompt user to continue
printf "\n\nCurrent kernel version: %s\n" "$(uname -r)"
printf "It will be updated to:  %s\n\nPress Enter to continue or Ctrl+C to cancel." "$kver"
read

printf '\nChecking compilation dependencies...\n\n'

# List of required packages for kernel compilation
pkgs="crossbuild-essential-amd64 bison flex rsync debhelper libelf-dev libncurses-dev libssl-dev zlib1g-dev bc python3 wget"

# Calculate total number of packages and maximum length for formatting
total=$(echo "$pkgs" | wc -w)
count=0
max_len=0

for p in $pkgs; do
  len=${#p}
  (( len > max_len )) && max_len=$len
done

# Define format string for progress display
format_str="\rProgress: %3d%% [%-20s] Now installing: %-${max_len}s"

# Install missing packages and track installation progress
for p in $pkgs; do
  if ! dpkg -l | grep -q "^ii $p$"; then
    count=$((count + 1))
    percent=$((count * 100 / total))
    unit=$((percent / 5))
    bar=$(printf '#%.0s' $(seq 1 $unit))

    printf "$format_str" "$percent" "$bar" "$p"
    apt-get install -y --no-install-recommends "$p" > /dev/null 2>&1
  fi
done

# Completion message for package installation
printf "\rProgress: %3d%% [%-20s] Installed $total packages.\n\n" 100 "$(printf '#%.0s' $(seq 1 20))"

printf '\n\nDownloading kernel sources...\n\n'

# Create directory and download the latest kernel source tarball
mkdir -p "kernel/linux-upstream-$kver"
cd "kernel/linux-upstream-$kver"
wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz

printf 'Extracting kernel sources...\n\n'
tar -zxf linux-master.tar.gz --strip-components=1
rm linux-master.tar.gz

# Configure and compile the new kernel version
yes '' | make localmodconfig
make menuconfig && time {
  make -j$(nproc) bindeb-pkg
  dpkg -i ~/kernel/*.deb
  
  printf '\n\neZkernel compilation successful for version: %s\n\nCompilation time:\n' "$kver"
}

# Define function to handle system reboot after kernel installation
reboot_system() {
  echo -e "\nSystem will reboot now.\n\nPress Enter to continue or Ctrl+C to cancel"
  
  read -rp '' && {
    cd ~
    rm -rf "kernel/linux-upstream-$kver"

    if ! grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
      echo "GRUB_TIMEOUT=1" >> /etc/default/grub || sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    fi

    update-grub >/dev/null 2>&1 && reboot
  }
}

# Execute the reboot function after kernel compilation
reboot_system
