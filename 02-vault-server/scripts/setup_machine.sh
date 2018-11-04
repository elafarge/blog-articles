#!/bin/bash
set -xe

DISKS=(/dev/sda /dev/sdb /dev/sdc)
PASSPHRASE=testpass

#
# This script sets up our server filesystem and installs archlinux onto it
# the rest of the script needs to be run in arch-chroot
#


# Erase a potentially previously existing RAID array
set +e

umount -R /mnt
swapoff /dev/mapper/root-swap

lvremove -f root

cryptsetup close cryptoroot

mdadm --stop /dev/md/boot
mdadm --stop /dev/md/root

for DISK in "${DISKS[@]}"
do
  mdadm --zero-superblock "${DISK}2"
  mdadm --zero-superblock "${DISK}3"
  dd if=/dev/zero of="${DISK}2" bs=1M count=4024 && sync
  dd if=/dev/zero of="${DISK}3" bs=1M count=4024 && sync
  (
    echo g
    echo w
  ) | fdisk "$DISK"
done
set -e

# Set up the physical disk layer
for DISK in "${DISKS[@]}"
do
  (
    # Create a new GPT partition table
    echo g

    # Create a 1MiB BIOS Boot partition at the beginning of the disk
    echo n
    echo 1
    echo ''
    echo '+1M'
    echo t
    echo 4

    # Create a 1GiB boot partition of type Linux RAID
    echo n
    echo 2
    echo ''
    echo '+1G'
    echo t
    echo 2
    echo 29

    # And finally, create a RAID partition on the rest of the disk
    echo n
    echo 3
    echo ''
    echo ''
    echo t
    echo 2
    echo 29

    # Write the partition table to disk and exit
    echo w
  ) | fdisk "$DISK"
done

sync

# Create the RAID array
mdadm --create \
  --verbose \
  --metadata=1.0 \
  --level=1 \
  --raid-devices=3 \
    /dev/md/boot \
    /dev/sda2 /dev/sdb2 /dev/sdc2

mdadm --create \
  --verbose \
  --metadata=1.2 \
  --level=5 \
  --chunk=256 \
  --raid-devices=3 \
    /dev/md/root \
    /dev/sda3 /dev/sdb3 /dev/sdc3

mdadm --detail --scan > /etc/mdadm.conf

# Encrypt it with LUKS and open the encrypted container
echo "$PASSPHRASE" | cryptsetup -q luksFormat --type luks2 /dev/md/root
echo "$PASSPHRASE" |  cryptsetup open /dev/md/root cryptoroot

# And layer LVM on top of that
pvcreate /dev/mapper/cryptoroot
vgcreate root /dev/mapper/cryptoroot
lvcreate -L 8G root -n swap
lvcreate -L 100G root -n root
lvcreate -l 100%FREE root -n data

# Finally create our OS filesystem
mkswap /dev/mapper/root-swap
mkfs.ext4 /dev/root/root
mkfs.ext4 /dev/root/data
mkfs.fat -F32 /dev/md/boot
swapon /dev/mapper/root-swap
mount /dev/root/root /mnt
mkdir -p /mnt/{boot,data}
mount /dev/root/data /mnt/data
mount /dev/md/boot /mnt/boot

# Pactstrap archlinux onto it
pacstrap /mnt base base-devel

# Generate the FSTab
genfstab -U /mnt >> /mnt/etc/fstab

# And finally, chroot in the target OS and run the in-chroot provisioning script
cp /tmp/configure_os.sh /mnt/root/configure_os.sh
cp /tmp/public_ssh_key /mnt/root/public_ssh_key
arch-chroot /mnt /bin/bash /root/configure_os.sh
