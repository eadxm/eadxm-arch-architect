#!/bin/bash

# Clear screen for a clean, custom user interface
clear
echo "=========================================================="
echo "          EADXM'S AUTOMATED ARCH ARCHITECT                "
echo "=========================================================="
echo ""
echo "Select your installation pathway:"
echo " [1] DUAL BOOT - Keep Windows, bypass the 100MB EFI restriction safely."
echo " [2] HARD NUKE - Wipe the drive, build a spacious 1GB EFI, clean install."
echo " [3] MANUAL ADVANCED - Launch interactive cfdisk to resize/create partitions manually."
echo " [4] TARGET NUKE - Auto-detect and wipe Windows C: drive only, replace with Arch."
echo " [5] DROP TO SHELL - Exit installer to a standard Arch Zsh terminal."
echo ""
read -p "Enter your choice (1-5): " USER_CHOICE

# Define target install drive (Adjust /dev/nvme0n1 or /dev/sda depending on your PC hardware)
TARGET_DRIVE="/dev/sda"
TARGET="/mnt"

# Base system package matrix (LibreOffice removed to keep it optional)
CORE_PKGS="base linux linux-firmware grub efibootmgr ntfs-3g networkmanager bluez bluez-utils blueman pipewire pipewire-pulse wireplumber brightnessctl flatpak"

# Track which grub configuration to run at the end
GRUB_OS_PROBER="true"
EFI_DIR="/boot"

case $USER_CHOICE in
    1)
        echo "====== PROCEEDING WITH SAFE DUAL-BOOT CONFIGURATION ======"
        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE $TARGET_DRIVE | grep vfat | awk '{print "/dev/"$1}')
        echo ", +" | sfdisk $TARGET_DRIVE --force --no-reread
        ARCH_ROOT="${TARGET_DRIVE}3"
        mkfs.ext4 -F $ARCH_ROOT
        mount $ARCH_ROOT $TARGET
        mkdir -p $TARGET/efi
        mkdir -p $TARGET/boot
        mount $WIN_EFI $TARGET/efi
        EFI_DIR="/efi"
        GRUB_OS_PROBER="false"
        ;;

    2)
        echo "====== CRITICAL WARNING: NUKING ALL WINDOWS PARTITIONS ======"
        echo "Clearing partition blocks in 5 seconds... Press Ctrl+C to abort!"
        sleep 5
        sgdisk --zap-all $TARGET_DRIVE
        sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" $TARGET_DRIVE
        sgdisk -n 2:0:0   -t 2:8300 -c 2:"ROOT" $TARGET_DRIVE
        partprobe $TARGET_DRIVE
        mkfs.vfat -F 32 "${TARGET_DRIVE}1"
        mkfs.ext4 -F "${TARGET_DRIVE}2"
        mount "${TARGET_DRIVE}2" $TARGET
        mkdir -p $TARGET/boot
        mount "${TARGET_DRIVE}1" $TARGET/boot
        EFI_DIR="/boot"
        GRUB_OS_PROBER="true"
        ;;

    3)
        echo "====== OPENING INTERACTIVE PARTITION WIZARD ======"
        echo "[INFO] Scanning available storage drives..."
        echo "--------------------------------------------------"
        lsblk -d -o NAME,SIZE,MODEL
        echo "--------------------------------------------------"
        read -p "Enter the drive disk to open in cfdisk (e.g., /dev/sda): " MANUAL_DISK
        cfdisk $MANUAL_DISK
        echo -e "\n=========================================================="
        echo "                 RESUMING ARCH ARCHITECT                  "
        echo "=========================================================="
        lsblk -o NAME,SIZE,TYPE,FSTYPE
        echo "----------------------------------------------------------"
        read -p "Enter the exact partition to use for Arch ROOT (e.g., /dev/sda3): " ARCH_ROOT
        read -p "Enter your system's EFI partition path (e.g., /dev/sda1): " ARCH_EFI
        read -p "Would you like to format $ARCH_ROOT to ext4? (y/N): " FORMAT_ROOT
        if [[ "$FORMAT_ROOT" =~ ^[Yy]$ ]]; then
            mkfs.ext4 -F $ARCH_ROOT
        fi
        mount $ARCH_ROOT $TARGET
        mkdir -p $TARGET/boot
        mount $ARCH_EFI $TARGET/boot
        EFI_DIR="/boot"
        read -p "Enable dual-boot Windows detection (os-prober)? (y/N): " MANUAL_PROBER
        if [[ "$MANUAL_PROBER" =~ ^[Yy]$ ]]; then
            GRUB_OS_PROBER="false"
        else
            GRUB_OS_PROBER="true"
        fi
        ;;

    4)
        echo "====== TARGET NUKE: HUNTING DOWN WINDOWS C: DRIVE ======"
        C_DRIVE=$(blkid -o device -t TYPE=ntfs | head -n 1)
        if [ -z "$C_DRIVE" ]; then
            echo "[WARNING] Unable to uniquely locate an NTFS C: partition automatically."
            lsblk -o NAME,SIZE,TYPE,FSTYPE
            echo "--------------------------------------------------"
            read -p "Please type the target Windows partition manually (e.g., /dev/sda2): " C_DRIVE
        fi
        WIN_EFI=$(lsblk -ln -o NAME,FSTYPE $TARGET_DRIVE | grep vfat | awk '{print "/dev/"$1}')
        echo -e "\n!!!!!!!!!!!!!!!!!!! DANGER ZONE !!!!!!!!!!!!!!!!!!!"
        echo "You are about to PERMANENTLY ERASE partition: $C_DRIVE"
        read -p "Type 'NUKE' to execute operation: " CONFIRM_NUKE
        if [ "$CONFIRM_NUKE" = "NUKE" ]; then
            echo "[INFO] Commencing target wipe on $C_DRIVE..."
            mkfs.ext4 -F $C_DRIVE
            mount $C_DRIVE $TARGET
            mkdir -p $TARGET/efi
            mkdir -p $TARGET/boot
            mount $WIN_EFI $TARGET/efi
            EFI_DIR="/efi"
            GRUB_OS_PROBER="true"
        else
            echo "[ABORT] Safety lock engaged. Returning to terminal."
            exit 1
        fi
        ;;

    5)
        echo "[INFO] Exiting Arch Architect menu. Handing over shell access."
        exit 0
        ;;
    *)
        echo "[ERROR] Invalid selection. Aborting script execution."
        exit 1
        ;;
esac

# =====================================================================
#             INTERACTIVE COMPONENT SELECTION ENGINE
# =====================================================================
clear
echo "=========================================================="
echo "          COMPONENT AND SOFTWARE SELECTION                "
echo "=========================================================="
echo ""

# 1. Choose Web Browser
echo "Select your primary web browser:"
echo " [1] Zen Browser (Flatpak - Optimized Layout)"
echo " [2] Firefox (Native - Stable Industry Standard)"
echo " [3] Brave Browser (Flatpak - Privacy Engine)"
echo " [4] Chromium (Native - Open Source Base)"
echo " [5] None (Skip browser installation)"
echo ""
read -p "Enter browser choice (1-5): " BROWSER_CHOICE

# 2. Choose LibreOffice suite
echo ""
echo "Do you require the LibreOffice productivity suite (~400MB space)?"
echo " [1] Yes, install LibreOffice-Fresh"
echo " [2] No, keep the build clean and light"
echo ""
read -p "Enter office suite choice (1-2): " OFFICE_CHOICE

# Process office selection
if [ "$OFFICE_CHOICE" == "1" ]; then
    CORE_PKGS="$CORE_PKGS libreoffice-fresh"
fi

# =====================================================================
#             CORE ARCH AUTOMATION DEPLOYMENT ENGINE
# =====================================================================
clear
echo "[INFO] Bootstrapping base system package matrix..."
pacstrap -K $TARGET $CORE_PKGS

# Configure GRUB parameters
echo "GRUB_DISABLE_OS_PROBER=$GRUB_OS_PROBER" >> $TARGET/etc/default/grub

echo "[INFO] Installing GRUB bootloader payload..."
arch-chroot $TARGET grub-install --target=x86_64-efi --efi-directory=$EFI_DIR --bootloader-id=ArchLinux --recheck

echo "[INFO] Running hardware-specific graphics configurations..."
if lspci | grep -iq nvidia; then
    echo "[INFO] Nvidia hardware detected. Deploying proprietary modules..."
    arch-chroot $TARGET pacman -S --noconfirm nvidia nvidia-utils
elif lspci | grep -iq amd; then
    echo "[INFO] AMD Radeon hardware detected. Deploying open-source drivers..."
    arch-chroot $TARGET pacman -S --noconfirm xf86-video-amdgpu
elif lspci | grep -iq intel; then
    echo "[INFO] Intel HD/Iris/Arc hardware detected. Deploying driver layers..."
    arch-chroot $TARGET pacman -S --noconfirm xf86-video-intel intel-media-driver
else
    echo "[INFO] No discrete GPU matched. Falling back to native kernel modesetting."
fi

# Deploy Flatpak ecosystem base
arch-chroot $TARGET flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install the selected browser
echo "[INFO] Deploying selected web browser environment..."
case $BROWSER_CHOICE in
    1)
        arch-chroot $TARGET flatpak install flathub app.zen_browser.zen -y
        ;;
    2)
        arch-chroot $TARGET pacman -S --noconfirm firefox
        ;;
    3)
        arch-chroot $TARGET flatpak install flathub com.brave.Browser -y
        ;;
    4)
        arch-chroot $TARGET pacman -S --noconfirm chromium
        ;;
    5)
        echo "[INFO] Skipping browser deployment."
        ;;
esac

echo "[INFO] Enabling hardware daemon services (Bluetooth, Networking)..."
arch-chroot $TARGET systemctl enable NetworkManager.service
arch-chroot $TARGET systemctl enable bluetooth.service

# Generate main GRUB configuration image matrix
arch-chroot $TARGET grub-mkconfig -o /boot/grub/grub.cfg

echo "=========================================================="
echo "   EADXM'S ARCH COMPILED! REBOOTING IN 5 SECONDS...       "
echo "=========================================================="
sleep 5
reboot