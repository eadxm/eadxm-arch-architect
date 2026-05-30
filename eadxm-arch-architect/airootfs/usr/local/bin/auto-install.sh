#!/bin/bash

# Clear screen for a clean, custom user interface
clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT                "
echo "=========================================================="
echo ""
echo "Windows installation footprint has been detected on this machine."
echo ""
echo "Select your installation pathway:"
echo " [1] DUAL BOOT - Keep Windows, bypass the 100MB EFI restriction safely."
echo " [2] NUKE WINDOWS - Wipe the drive, build a spacious 1GB EFI, clean install."
echo ""
read -p "Enter your choice (1 or 2): " USER_CHOICE

# Define target install drive (Adjust /dev/nvme0n1 or /dev/sda depending on your PC hardware)
TARGET_DRIVE="/dev/sda"
TARGET="/mnt"

# Define default package list for the target system build
CORE_PKGS="base linux linux-firmware grub efibootmgr ntfs-3g networkmanager bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl libreoffice-fresh flatpak"

if [ "$USER_CHOICE" == "1" ]; then
    echo "====== PROCEEDING WITH SAFE DUAL-BOOT CONFIGURATION ======"
    
    # Locate the tiny Windows EFI partition dynamically
    WIN_EFI=$(lsblk -ln -o NAME,FSTYPE $TARGET_DRIVE | grep vfat | awk '{print "/dev/"$1}')
    
    # Carve out remaining drive space for Arch Linux root partition
    echo ", +" | sfdisk $TARGET_DRIVE --force --no-reread
    ARCH_ROOT="${TARGET_DRIVE}3"
    
    # Format the fresh Linux partition
    mkfs.ext4 -F $ARCH_ROOT
    
    # Mount execution paths using the Extended Boot Split method to save EFI space
    mount $ARCH_ROOT $TARGET
    mkdir -p $TARGET/efi
    mkdir -p $TARGET/boot
    mount $WIN_EFI $TARGET/efi
    
    # Bootstrap the base system files
    pacstrap -K $TARGET $CORE_PKGS
    
    # Force activate internal GRUB multi-boot tracking parameters
    echo "GRUB_DISABLE_OS_PROBER=false" >> $TARGET/etc/default/grub
    
    # Install GRUB to the motherboard NVRAM pointing to /efi instead of /boot
    arch-chroot $TARGET grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=ArchLinux --recheck

else
    echo "====== CRITICAL WARNING: NUKING ALL WINDOWS PARTITIONS ======"
    echo "Clearing partition blocks in 5 seconds... Press Ctrl+C to abort!"
    sleep 5
    
    # Wipe the drive completely clean
    sgdisk --zap-all $TARGET_DRIVE
    
    # Re-partition drive: Allocation 1 = 1GB EFI layout, Allocation 2 = Rest of Drive for Root
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" $TARGET_DRIVE
    sgdisk -n 2:0:0   -t 2:8300 -c 2:"ROOT" $TARGET_DRIVE
    
    # Sync partition changes with kernel
    partprobe $TARGET_DRIVE
    
    # Format partitions with large spacious file structures
    mkfs.vfat -F 32 "${TARGET_DRIVE}1"
    mkfs.ext4 -F "${TARGET_DRIVE}2"
    
    # Mount paths safely since our new native EFI partition is 1GB large
    mount "${TARGET_DRIVE}2" $TARGET
    mkdir -p $TARGET/boot
    mount "${TARGET_DRIVE}1" $TARGET/boot
    
    # Bootstrap the base system files
    pacstrap -K $TARGET $CORE_PKGS
    
    # Windows is gone, so keep os-prober disabled securely
    echo "GRUB_DISABLE_OS_PROBER=true" >> $TARGET/etc/default/grub
    
    # Install GRUB directly to our new large 1GB /boot structure
    arch-chroot $TARGET grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=ArchLinux --recheck
fi

# --- AUTOMATED HARDWARE CONFIG RUNS ONSITE REGARDLESS OF CHOICE ---

echo "Running hardware-specific graphics configurations..."
if lspci | grep -iq nvidia; then
    arch-chroot $TARGET pacman -S --noconfirm nvidia nvidia-utils
elif lspci | grep -iq amd; then
    arch-chroot $TARGET pacman -S --noconfirm xf86-video-amdgpu
fi

echo "Deploying and compiling application desktop wrappers..."
arch-chroot $TARGET flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
arch-chroot $TARGET flatpak install flathub app.zen_browser.zen -y

echo "Enabling hardware daemon services (Bluetooth, Networking)..."
arch-chroot $TARGET systemctl enable NetworkManager.service
arch-chroot $TARGET systemctl enable bluetooth.service

# Generate main GRUB configuration image matrix
arch-chroot $TARGET grub-mkconfig -o /boot/grub/grub.cfg

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
reboot