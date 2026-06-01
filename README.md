# Eadxm Automated Arch Architect

An automated, hyper-optimized Arch Linux deployment system built to turn a tedious multi-hour command-line install into a **3-minute, flawless deployment**. Written entirely in pure Bash, it dynamically scales based on your hardware, firmware, and connectivity.

---

## 🛠️ The Core Installation Pipeline

To understand what happens under the hood when you boot the ISO, here is how the engine processes your hardware:

```text
[ Boot ISO ] ➔ [ Detect Firmware: UEFI vs Legacy BIOS ]
                      │
                      ├─► UEFI ──► GPT Drive Table ──► 1GB EFI + Root
                      └─► BIOS ──► MBR Drive Table ──► 100% Root (No EFI)
│
[ Provision Packages via pacstrap ] ➔ [ Inject Hardware Drivers ] ➔ [ Install GRUB ] ➔ [ Done ]                      
```
---

## 📦 What gets installed? (The Core Software Matrix)

The system bakes in the absolute essentials for a cutting-edge desktop experience, removing all the manual configuration work.

### 1. System Core
* **Kernel:** Stable Linux Rolling Kernel (`linux`) & Open-source microcode firmware updates (`linux-firmware`).
* **Bootloader:** Universal GRUB framework supporting modern `efibootmgr` logic and legacy `i386-pc` sectors.
* **Storage Systems:** Integrated `os-prober` for safe dual-boot detection and `ntfs-3g` to interact with Windows drives seamlessly.

### 2. Desktop Foundations
* **Display Infrastructure:** Natively bundles full `xorg-server` frameworks and modern Wayland compositing gates.
* **Display Manager:** Modern, themeable `sddm` login manager enabled automatically on boot.
* **Audio & Connectivity:** Driven completely by high-fidelity `pipewire`, `wireplumber`, and `NetworkManager`.

### 3. Your Desktop Workspace (Choose 1)
During installation, the engine will prompt you to choose your interface footprint:
* **Hyprland:** A modern, hardware-accelerated dynamic tiling window manager wrapped in `waybar` and `kitty`.
* **KDE Plasma:** A feature-rich, high-performance desktop framework tailored for familiarity and absolute customization.
* **XFCE:** An ultra-lightweight, blazing-fast workspace built for maximum resource stability on older hardware (perfect for older laptops).

---

## 🚀 Step-by-Step Installation Guide

### 📥 Step 1: Download & Flash
1. Head over to the [GitHub Releases Page](/../../releases) and grab the latest compiled `.iso` core image.
2. Flash the ISO to a USB drive using `dd` on Linux, or Rufus (choose **DD Mode**) on Windows.

### 🥾 Step 2: Boot the Target Hardware
1. Plug the USB into your target machine and mash your motherboard's boot-menu key (usually `F12`, `F11`, `F2` or `Del`).
2. Select your USB drive. The live Arch image will load and automatically launch the **Arch Architect** interface menu.

### 🎛️ Step 3: Run the Wizard
The menu will guide you through three instant steps:
1. **Connection Architecture:** Select **Online Mode** to sync the absolute newest package pools over Wi-Fi, or **Offline Mode** to deploy air-gapped without an internet link.
2. **Storage Provisioning:** Choose **Dual-Boot** to safely carve space alongside Windows, **Hard Nuke** to clean-wipe the entire drive, or **Target Nuke** to cleanly dissolve just your Windows `C:` drive partition.
3. **Software Configuration:** Pick your favorite web browser (Firefox, Chromium, Zen, or Brave) and choose your preferred Desktop Workspace environment.

---

## 🚨 Fail-Safe Emergency Recovery Mode

Things happen during manual installs. That’s why **Architect** features an internal **Telemetry Error Trapping Engine**. 

If a hard drive mount drops out, a partition alignment faults, or a script command fails mid-install, the script will instantly trigger its emergency safety loop:
1. It immediately halts formatting or writing to prevent corruption.
2. It completely unmounts all system folders safely to lock down data integrity.
3. It hands you a live **Root Zsh Recovery Shell** on-screen so you can diagnose the system, fix lines, or type `exit` to cleanly reboot.
