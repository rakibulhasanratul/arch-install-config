#! /bin/sh

## time and date config
echo 'Setting time and date'
timedatectl set-ntp true
timedatectl set-timezone Asia/Dhaka
timedatectl status

cat << 'EOF'
Now this will execute:
  mkfs.fat -F32 /dev/nvme0n1p1
  mkfs.ext4 /dev/nvme0n1p2
  mkfs.btrfs -f /dev/nvme0n1p3
  mount /dev/nvme0n1p3 /mnt
  btrfs su cr /mnt/@
  btrfs su cr /mnt/@pkg
  btrfs su cr /mnt/@log
  btrfs su cr /mnt/@snapshots
  umount /mnt
  mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p3 /mnt
  mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
  mount /dev/nvme0n1p2 /mnt/boot
  mkdir -p /mnt/boot/efi
  mount /dev/nvme0n1p1 /mnt/boot/efi
  mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p3 /mnt/var/log
  mount -o noatime,compress=zstd,subvol=@pkg /dev/nvme0n1p3 /mnt/var/cache/pacman/pkg
  mount -o noatime,compress=zstd,subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots
  mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p4 /mnt/home
EOF

mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkfs.btrfs -f /dev/nvme0n1p3
mount /dev/nvme0n1p3 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@pkg
btrfs su cr /mnt/@log
btrfs su cr /mnt/@snapshots
umount /mnt
mount -o noatime,compress=zstd,subvol=@ /dev/nvme0n1p3 /mnt
mkdir -p /mnt/{boot,home,var/log,var/cache/pacman/pkg,.snapshots}
mount /dev/nvme0n1p2 /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
mount -o noatime,compress=zstd,subvol=@log /dev/nvme0n1p3 /mnt/var/log
mount -o noatime,compress=zstd,subvol=@pkg /dev/nvme0n1p3 /mnt/var/cache/pacman/pkg
mount -o noatime,compress=zstd,subvol=@snapshots /dev/nvme0n1p3 /mnt/.snapshots
mount -o noatime,compress=zstd,subvol=@home /dev/nvme0n1p4 /mnt/home

echo 'Installing base system'
pacstrap -K /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs networkmanager sudo nano vim git fish neovim grub wget curl gvfs gvfs-mtp mtpfs libmtp tree-sitter-cli efibootmgr

echo 'Generating fstab'
genfstab -U /mnt >> /mnt/etc/fstab

echo Chrooting
arch-chroot /mnt
