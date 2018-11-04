#!/bin/bash
set -xe

HOSTNAME=truman
USERNAME=etienne

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo "$HOSTNAME" > /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.example.com $HOSTNAME
EOF

pacman -S vim zsh openssh sudo git htop dropbear grub intel-ucode
useradd -m -g users -G wheel -s /bin/zsh etienne

echo "set the root password"
passwd

echo "Add the wheel group to the list of sudoers"
visudo

cd /home/etienne
su etienne <<EOSU
git clone https://aur.archlinux.org/mkinitcpio-netconf.git
cd mkinitcpio-netconf
makepkg -si
cd -
rm -rf mkinitcpio-netconf

# Let's get dropbear, a lightweight but secure SSH daemon that can be embedded
# in the initramfs easily.
pacman -S dropbear
git clone https://aur.archlinux.org/mkinitcpio-dropbear.git
cd mkinitcpio-dropbear
makepkg -si
cd -
rm -rf mkinitcpio-dropbear

# That's also required to (for the encryptssh hook)
git clone https://aur.archlinux.org/mkinitcpio-utils.git
cd mkinitcpio-utils
makepkg -si
cd -
rm -rf mkinitcpio-utils
EOSU

# Configure the initramfs
sed -i '/MODULES=/c\MODULES=(igb)' /etc/mkinitcpio.conf
sed -i '/HOOKS=/c\HOOKS=(base udev autodetect modconf keyboard keymap block mdadm_udev netconf dropbear encryptssh lvm2 filesystems fsck)' /etc/mkinitcpio.conf

cp /root/public_ssh_key /etc/dropbear/root_key
chmod 600 /etc/dropbear/root_key

mkinitcpio -p linux

# Bootloader configuration
grub-install --target=i386-pc /dev/sda
grub-install --target=i386-pc /dev/sdb
grub-install --target=i386-pc /dev/sdc

sed -i '/GRUB_CMDLINE_LINUX_DEFAULT=/c\GRUB_CMDLINE_LINUX_DEFAULT="quiet nomodeset"' /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX=/c\GRUB_CMDLINE_LINUX="ip=ip=:::::eth0:dhcp:ip=:::::eth1:dhcp cryptdevice=UUID=<the-uuid-of-your-encrypted-raid-array>:cryptoroot root=/dev/mapper/root-root rw"' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg
