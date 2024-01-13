#!/bin/bash

# Print a welcome message
printf '\nWelcome '; whoami; echo -e 'to eZarch install\n\nCreating partitions...\n'

# Create partition and format it
parted -s /dev/sda mklabel msdos
parted -s /dev/sda mkpart primary ext4 1MiB 102000MiB
parted -s /dev/sda set 1 boot on
mkfs.ext4 /dev/sda1
mount -vt ext4 /dev/sda1 /mnt
mkdir /mnt/boot

# Print partition information
parted -ls
printf '\n'

# Install essential packages and set up base system
pacstrap -K /mnt base-devel linux linux-firmware amd-ucode efibootmgr grub networkmanager sudo vi zstd

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the installed system and configure it
arch-chroot /mnt <<EOF
# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo -e "LANG=en_US.UTF-8" >> /etc/locale.conf

# Set hostname
echo -e "arch" >> /etc/hostname

# Set hosts file
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch.domain arch" >> /etc/hosts

# Install bootloader
printf '\nInstalling bootloader...\n'
grub-install /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg
sed -i 's/set timeout=5/set timeout=1/' /boot/grub/grub.cfg

# Enable services
printf '\nEnabling services...\n'
systemctl enable NetworkManager
systemctl enable systemd-networkd
systemctl enable systemd-resolved

# Set root password
printf '\nChoose Root password.\n'
passwd

# Create a user and set password
useradd --groups wheel --create-home user
usermod --append --groups wheel user
echo -e 'wheel ALL=(ALL) ALL\nuser ALL=(ALL:ALL) ALL' > /etc/sudoers.d/01
echo -e '\nChoose User password:'
passwd user

# Print installation complete message
printf '\neZarch install complete.\n'
EOF
