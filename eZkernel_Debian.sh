#!/bin/bash

# --- Configuration ---
NUM_STEPS=3
KERNEL_DIR="$HOME/kernel"  # Use a defined, portable directory
# ----------------------

# --- Functions ---
step() {
  percent=$(( ($1 + 1) * 100 / NUM_STEPS ))
  printf "\rChecking kernels versions... (%d%%)" $percent
}

# --- Script Start ---

clear
printf "\n\nWelcome %s, to eZkernel for Debian.\n\nThe latest linux kernel from git.kernel.org will be compiled and installed.\n\n" "$(whoami)"

step 0

apt update -y > /dev/null 2>&1

step 1 || {
  echo -e "\n\nConnection error. Exiting.\n"
  exit 1
}

apt install -y curl > /dev/null 2>&1

step 2

# Get latest kernel version
kver=$(curl -s https://www.kernel.org/ | grep -oP '(?<=<strong>)[^<]+(?=</strong>)' | head -n 2 | tail -n 1)

printf "\n\nCurrent kernel version: %s\n" "$(uname -r)"
printf "It will be updated to:  %s\n\nPress Enter to continue or Ctrl+C to cancel." "$kver"

read

printf '\nChecking compilation dependencies...\n\n'

pkgs="crossbuild-essential-amd64 bison flex rsync debhelper libelf-dev libncurses-dev libssl-dev zlib1g-dev bc python3 wget"
total=$(echo $pkgs | wc -w)
count=0
max_len=0
for p in $pkgs; do
  len=${#p}
  (( len > max_len )) && max_len=$len
done
format_str="\rProgress: %3d%% [%-20s] Now installing: %-${max_len}s"

for p in $pkgs; do
  if ! dpkg -l | grep -q "^ii $p"; then
    apt install -y "$p" > /dev/null 2>&1
    if [ $? -ne 0 ]; then  # Check for installation failure
      echo "Error installing package: $p"
      exit 1
    fi
  fi
  count=$((count + 1))
  percent=$((count * 100 / total))
  unit=$((percent / 5))
  bar=$(printf '#%.0s' $(seq 1 $unit))
  printf "$format_str" "$percent" "$bar" "$p"
done

printf "\rProgress: %3d%% [%-20s] Installed $total packages.\n" 100 "$bar"

printf '\n\nDownloading kernel sources...\n\n'

mkdir -p "$KERNEL_DIR"
cd "$KERNEL_DIR"

wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz
if [ $? -ne 0 ]; then
  echo "Error downloading kernel sources"
  exit 1
fi

printf 'Extracting kernel sources...\n\n'

tar -zxf linux-master.tar.gz --strip-components=1
if [ $? -ne 0 ]; then
  echo "Error extracting kernel sources"
  exit 1
fi

rm linux-master.tar.gz

# --- Kernel Configuration ---
# Use 'make olddefconfig' for automation.  Consider adding a way to
# customize the configuration if the user wants.
yes '' | make localmodconfig
make menuconfig # <--- PROBLEM: Blocking, interactive!
# make olddefconfig # <- Automate with this if you don't want interactive

# --- Kernel Compilation ---
if ! make -j$(nproc) bindeb-pkg; then
  echo "Error compiling kernel"
  exit 1
fi

if ! dpkg -i ~/kernel/*.deb; then
  echo "Error installing kernel packages"
  exit 1
fi

printf '\n\neZkernel compilation successful for version: %s\n\nCompilation time:\n' "$kver"

# --- Reboot ---
read -p 'System will reboot now. Press Enter to continue or Ctrl+C to cancel: '
if [ -z "$REPLY" ]; then
  reboot
fi

cd
rm -rf "$KERNEL_DIR"

! grep -q "^GRUB_TIMEOUT=" /etc/default/grub && echo "GRUB_TIMEOUT=1" >> /etc/default/grub || sed -i 's/^GRUB_TIMEOUT=[0-9]\+/GRUB_TIMEOUT=1/' /etc/default/grub
update-grub > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Error updating grub"
  exit 1
fi
