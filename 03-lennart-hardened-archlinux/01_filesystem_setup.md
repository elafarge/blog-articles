Step 1 - Setting up the filesystem
==================================

0 - Boot a recent ArchLinux ISO bootable media
----------------------------------------------

Make sure that you first go in your BIOS and set SecureBoot in "Setup Mode",
otherwise, you won't be able to boot the media and/or configure SecureBoot later
on in the installation process.

1 - Disk partitioning
---------------------

Let's create two partitions: the EFI System partition we'll also mount as a
/boot partition and a encrypted partition which will serve as a LUKS container.

Regarding the LUKS container, we'll just make it an LVM volume with the root
partition and a swap partition but feel free to partition it the way you wish.

```shell
fdisk /dev/<yourdisk>
```

1. Create a GPT partition table with `g`
2. Type `n` to create an EFI System partion, give it 1GiB of size (`+1G`)
3. Then `t`, then `Enter`, then `1` to change its type to "EFI System"
4. Create the second partition with `n` (the default `Linux Filesystem` type is
   fine, no need to change it) spanning the rest of the disk.
5. Write the partition table to disk and exit with `w`

Example `lsblk` output:
```shell
root@archiso ~ # lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0 689.8M  1 loop /run/archiso/airootfs
sda           8:0    1  28.9G  0 disk
├─sda1        8:1    1   782M  0 part /run/archiso/bootmnt
└─sda2        8:2    1    13M  0 part
nvme0n1     259:0    0 476.9G  0 disk
├─nvme0n1p1 259:7    0     1G  0 part
└─nvme0n1p2 259:8    0 475.9G  0 part
```

2. Encrypting the root disk
---------------------------

```shell
cryptsetup luksFormat <YOUR_SECOND_DISK_PARTITION>
````

Then unlock the crypto container

```shell
cryptsetup open <YOUR_SECOND_DISK_PARTITION> cryptoroot
```

3. Setting up our partition table in the encrypted container
------------------------------------------------------------

```shell
# Register our encrypted container as a Physical LVM Volume
pvcreate /dev/mapper/cryptoroot

# Let's create and bind a volume group and bind it to our Physical Volume
vgcreate root /dev/mapper/cryptoroot

# And let's layer our logical volumes on top of
lvcreate -L 16G root -n swap
lvcreate -l 100%FREE root -n root
```

4. Format mount and let's go
----------------------------

Format:
```shell
mkswap /dev/mapper/root-swap

mkfs.ext4 /dev/root/root

mkfs.fat -F32 <YOUR_FIRST_DISK_PARTITION>
````

Mount:
```shell
swapon /dev/mapper/root-swap

mount /dev/root/root /mnt
mkdir -p /mnt/efi
mount <YOUR_FIRST_DISK_PARTITION> /mnt/efi
```
