#!/bin/bash

# --- Configuration ---
NUM_STEPS=3
KERNEL_DIR="$HOME/kernel"
# ----------------------

# --- Functions ---

# Function: display_step
# Displays a progress message
display_step() {
  local step=$1
  local total=$2
  local percent=$(( ($step * 100) / $total ))
  printf "\rChecking kernels versions... (%d%%)" $percent
}

# Function: check_dependencies
# Checks and installs dependencies
check_dependencies() {
  local pkgs="$1"
  local total=$(echo "$pkgs" | wc -w)
  local count=0
  local max_len=0
  for p in $pkgs; do
    len=${#p}
    (( len > max_len )) && max_len=$len
  done
  local format_str="\rProgress: %3d%% [%-20s] Now installing: %-${max_len}s"

  for p in $pkgs; do
    if ! dpkg -l | grep -q "^ii $p"; then
      apt install -y "$p" > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "Error installing package: $p"
        return 1  # Indicate failure
      fi
    fi
    count=$((count + 1))
    percent=$((count * 100 / total))
    unit=$((percent / 5))
    bar=$(printf '#%.0s' $(seq 1 $unit))
    printf "$format_str" "$percent" "$bar" "$p"
  done

  printf "\rProgress: %3d%% [%-20s] Installed $total packages.\n" 100 "$bar"
  return 0  # Indicate success
}

# Function: download_and_extract
# Downloads and extracts the kernel sources
download_and_extract() {
  mkdir -p "$KERNEL_DIR"
  cd "$KERNEL_DIR"

  wget https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/snapshot/linux-master.tar.gz
  if [ $? -ne 0 ]; then
    echo "Error downloading kernel sources"
    return 1
  fi

  tar -zxf linux-master.tar.gz --strip-components=1
  if [ $? -ne 0 ]; then
    echo "Error extracting kernel sources"
    return 1
  fi

  rm linux-master.tar.gz
  return 0
}

# Function: configure_kernel
configure_kernel() {
  yes '' | make localmodconfig
  make menuconfig # Consider using make olddefconfig for automation
  return 0
}

# Function: compile_kernel
compile_kernel() {
  # Use time to measure the compilation time
  time make -j$(nproc) bindeb-pkg

  if [ $? -ne 0 ]; then
    echo "Error compiling kernel"
    return 1
  fi

  return 0
}

# Function: install_kernel
install_kernel() {
  if ! dpkg -i ~/kernel/*.deb; then
    echo "Error installing kernel packages"
    return 1
  fi
  return 0
}

# Function: reboot_system
reboot_system() {
  read -p 'System will reboot now. Press Enter to continue or Ctrl+C to cancel: '
  if [ -z "$REPLY" ]; then
    reboot
  fi
  return 0
}

# --- Main Script ---

# Display progress steps
display_step 1 3
# Check dependencies
if ! check_dependencies "crossbuild-essential-amd64 bison flex rsync debhelper libelf-dev libncurses-dev libssl-dev zlib1g-dev bc python3 wget"; then
  echo "Error checking dependencies. Exiting."
  exit 1
fi

display_step 2 3
# Download and extract kernel sources
if ! download_and_extract; then
  echo "Error downloading/extracting kernel. Exiting."
  exit 1
fi

display_step 3 3

# Configure the kernel
configure_kernel

# Compile the kernel
compile_kernel

# Install the kernel
install_kernel

# Reboot the system
reboot_system

# Clean up
rm -rf "$KERNEL_DIR"

exit 0
