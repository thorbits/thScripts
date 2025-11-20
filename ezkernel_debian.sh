#!/bin/bash
#
#    _______
#    \_   _/
#      |_|horbits 
#
#    eZkernel for Debian
#    Automated kernel compilation and installation script

clear
printf "\n\nWelcome %s, to eZkernel for Debian.\n\nThe latest linux kernel from git.kernel.org will be compiled and installed.\n\n" "$USER"

# Progress indicator for initial setup steps
STEPS=3
step() {
    local current_step=$1
    local percent=$(( (current_step + 1) * 100 / STEPS ))
    printf "\rChecking system and dependencies... (%d%%)" "$percent"
}

step 0
if ! apt-get update -qq; then
    printf "\n\nConnection error. Exiting.\n"
    exit 1
fi

step 1
apt-get install -y curl > /dev/null 2>&1

step 2
KVER=$(curl -fsSL https://www.kernel.org | grep -oP '(?<=<strong>)[^<]+(?=</strong>)' | sed -n '2p')

printf "\rChecking system and dependencies... Done  \n\n"
printf "Current kernel version: %s\n" "$(uname -r)"
printf "It will be updated to:  %s\n\n" "$KVER"
printf "Press Enter to continue or Ctrl+C to cancel.\n"
read -r

# Define required packages
printf 'Checking compilation dependencies...\n\n'
PKGS="build-essential libdw-dev libelf-dev zlib1g-dev libncurses-dev libssl-dev bison bc flex rsync debhelper python3 wget"
TOTAL=$(echo "$PKGS" | tr ' ' '\n' | wc -l)

# Initialize progress tracking variables
COUNT=0
MAX_LEN=0

# Determine longest package name for aligned output
for P in $PKGS; do
    LEN=${#P}
    (( LEN > MAX_LEN )) && MAX_LEN=$LEN
done

# Format string for progress bar
FORMAT_STR="\rProgress: %3d%% [%-20s] Now installing: %-${MAX_LEN}s"

# Install packages with progress bar
for P in $PKGS; do
    if ! dpkg-query -W -f='${Status}\n' "$P" 2>/dev/null | grep -q "install ok installed"; then
        COUNT=$((COUNT + 1))
        PERCENT=$((COUNT * 100 / TOTAL))
        UNIT=$((PERCENT / 5))
        BAR=$(printf '#%.0s' $(seq 1 $UNIT))
        printf "$FORMAT_STR" "$PERCENT" "$BAR" "$P"
        apt-get install -y --no-install-recommends "$P" > /dev/null 2>&1
    fi
done

printf "\rProgress: 100%% [%-20s] Installed %d packages.\n\n" "$BAR" "$TOTAL"
printf "Downloading kernel sources...\n\n"

# Create working directory and download kernel source
mkdir -p "$HOME/kernel/linux-upstream-$KVER"
cd "$HOME/kernel/linux-upstream-$KVER"
wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz

# Extract source archive
printf 'Extracting kernel sources...\n\n'
tar -zxf linux-master.tar.gz --strip-components=1 && rm linux-master.tar.gz

# Configure kernel (use current config as base, require manual config confirmation to proceed to compilation)
yes '' | make localmodconfig

# Compile kernel and create Debian packages
if make menuconfig && time make -j$(nproc) bindeb-pkg; then
    # Install generated .deb packages
    cd "$HOME/kernel"
    dpkg -i linux-*.deb
    
    printf '\n\neZkernel compilation successful for version: %s\n\n' "$KVER"
    printf 'Compilation time:\n'
else
    printf "\n\nCompilation or installation error. Exiting.\n"
    exit 1
fi

# Reboot system function
reboot_system() {
    printf "\nSystem will reboot now.\n\n"
    printf "Press Enter to continue or Ctrl+C to cancel"
    read -rp ''
    
    # Clean up kernel source directory
    cd "$HOME"
    rm -rf "$HOME/kernel"
    
    # Set GRUB timeout to 1 second
    if grep -q "^GRUB_TIMEOUT=" /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
    else
        echo "GRUB_TIMEOUT=1" >> /etc/default/grub
    fi
    
    update-grub >/dev/null 2>&1
    reboot
}

# Call reboot function
reboot_system
