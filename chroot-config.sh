#!/bin/bash

## This script should be run AFTER chroot-ing into the new installation
## Usage: arch-chroot /mnt, then run this script

echo "Setting Timezone..."
ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime
hwclock --systohc

echo "Configuring locale"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "Setting hostname"
hostname="archlinux"
echo "$hostname" > /etc/hostname

# Create hosts file
cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
EOF

echo "Enabling multilib repository"
if grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "Multilib already enabled"
else
    # Uncomment [multilib] section - need to uncomment both lines
    sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    echo "Multilib repository enabled"
fi

echo "Setting root password ++"
passwd

echo "Creating user account --"
username="ratul"

useradd -m -G wheel,audio,video,optical,storage -s /usr/bin/fish -c "Rakibul Hasan Ratul" "$username"
echo "User $username (Rakibul Hasan Ratul) created with fish as default shell"
echo "Setting password for $username:"
passwd "$username"


echo "Configuring sudo"
if ! grep -q "^Defaults pwfeedback" /etc/sudoers; then
    # Use visudo to safely add pwfeedback
    echo "Defaults pwfeedback" | EDITOR='tee -a' visudo > /dev/null 2>&1
    echo "Password feedback enabled for sudo"
else
    echo "Password feedback already enabled"
fi

# Enable wheel group for sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
echo "User $username added to wheel group with sudo privileges"

echo "Configuring sudo for unattended installation"
cat > "/etc/sudoers.d/10-$username-pacman" << EOF
# Allow user $username to install packages with pacman without a password
$username ALL=(ALL) NOPASSWD: /usr/bin/pacman
EOF
chmod 440 "/etc/sudoers.d/10-$username-pacman"
echo "User $username can now run 'sudo pacman' without a password."

echo "Configuring GRUB kernel parameters"

# Backup original grub config
cp /etc/default/grub /etc/default/grub.backup

# Get current parameters
current_line=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub)
current_params=$(echo "$current_line" | sed 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')

# Define parameters to remove
params_to_remove=(
    "quiet"
)

# Define parameters to add/update
params_to_add=(
    "zswap.enabled=1"
    "zswap.compressor=zstd"
    "zswap.max_pool_percent=20"
    "zswap.zpool=z3fold"
    "systemd.show_status=1"
    "loglevel=3"
)

# Start with current parameters
result_params="$current_params"

# Remove unwanted parameters
for param in "${params_to_remove[@]}"; do
    result_params=$(echo "$result_params" | sed "s/\b${param}\b//g")
done

# Process each parameter to add/update
for param in "${params_to_add[@]}"; do
    # Extract key from key=value
    key=$(echo "$param" | cut -d'=' -f1)

    # Check if key already exists (with any value)
    if echo "$result_params" | grep -q "\b${key}="; then
        # Replace existing value
        result_params=$(echo "$result_params" | sed "s/\b${key}=[^ ]*/${param}/g")
    else
        # Add new parameter
        result_params="$result_params $param"
    fi
done

# Clean up extra spaces
result_params=$(echo "$result_params" | sed 's/  */ /g' | sed 's/^ //;s/ $//')

# Update GRUB config
sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/d' /etc/default/grub
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$result_params\"" >> /etc/default/grub

echo "GRUB parameters configured:"
echo "  - Zswap: enabled (zstd, z3fold, 20% RAM)"
echo "  - Boot mode: verbose with systemd status"
echo "  - Kernel log level: 3 (errors + warnings)"

echo "Installing GRUB bootloader (UEFI)"
# Install GRUB for UEFI
grub-install --target=x86_64-efi --efi-directory=/boot/efi --boot-directory=/boot --bootloader-id=GRUB

# Generate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg
echo "GRUB installed and configured"

systemctl enable NetworkManager

# Install AMD GPU drivers first (before Steam, which depends on lib32-vulkan-driver
# — without explicit AMD packages, --noconfirm may auto-select nvidia as the provider)
echo "Installing AMD GPU drivers"
pacman -Sy --noconfirm mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon libva-mesa-driver

echo 'Installing paru'
# The entire process of cloning and building is done as the non-root user
# to avoid permission issues and follow best practices for makepkg.
sudo -u "$username" bash -c '
    set -e
    cd /tmp/
    rm -rf /tmp/paru
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
'
echo "paru installed"

echo "Installing softwares"
sudo -u $username paru -Sy --noconfirm brave-bin openbangla-keyboard-bin ttf-freebanglafont ttf-indic-otf ttf-whatsapp-emoji gnome-characters ttf-firacode-nerd gnome-shell gdm gnome-control-center gnome-settings-daemon gnome-keyring nautilus sushi gnome-calculator gnome-browser-connector gnome-tweaks loupe ghostty steam gnome-system-monitor celluloid firefox pipewire-jack pipewire-pulse starship wl-clipboard xclip htop ripgrep noto-fonts-cjk noto-fonts-extra ibus-libpinyin gcc npm pnpm cargo python python-pip uv lazygit tmux opencode visual-studio-code-bin antigravity windsurf

echo Remove Unwanted Dependencies
pacman -Rns vim noto-fonts-emoji

echo 'Enabling GDM'
systemctl enable gdm

echo "Creating swapfile"
mkdir -p /swap
btrfs filesystem mkswapfile --size 11G --uuid clear /swap/swapfile
chmod 600 /swap/swapfile
mkswap /swap/swapfile
swapon /swap/swapfile

# Add to fstab
echo "/swap/swapfile none swap defaults 0 0" >> /etc/fstab

echo
echo
echo Completed
