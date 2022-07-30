### System installation & Chroot

Let's install the target OS in the `/mnt` directory:
```shell
pacstrap /mnt linux base base-devel
```

##### Generating `fstab`

On Linux, the `/etc/fstab` file describes partitions that should be mounted
automatically after boot. Despite our orthodox LUKS < LVM topology,
`genfstab` generates it for us perfectly:
```shell
genfstab -U /mnt >> /mnt/etc/fstab
```

##### Chroot-ing

Let's [chroot](TODO) into our new OS !

```shell
arch-chroot /mnt
```

### System configuration prerequisites

```shell
# Here, I'm configuring the server timezone to Europe/Paris, choose whatever
# best fits the location of the server, or yours
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

# Set your laptop's hostname (don't forget to update /etc/hosts as well)
echo "testlaptop" > /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1 localhost
EOF

# Choose the keymap ONLY IF YOU NEED TO (used in TTYs AND for entering your passphrase)
cat <<EOF > /etc/vconsole.conf
KEYMAP=dvorak-programmer
EOF
```

Install some software you may need, at least a text editor. For the networking
stack, we'll use systemd-networkd which should already be there but let's also
install iwd in case
```shell
pacman -S iwd zsh neovim openssh sudo lvm2 intel-ucode mesa sbctl tpm2-tss tpm2-tools tpm2-abrmd
```

### Boot configuration

Let's configure the initramfs (via mkinitcpio) so that we have all the necessary
systemd-hooks for root disk decryption, edit `/etc/mkinitcpio.conf`

```
# Enable early KMS for intel processor
MODULES=(... i915 ...)

# Load the necessary module in the correct order
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt lvm2 filesystems fsck)
```

Configure hard disk decryption at boot time with systemd-boot
```shell
# Run
#   lsblk -o NAME,UUID
# to figure the UUID of the encrypted container partition out
cat <<EOF /etc/crypttab.initramfs
cryptoroot <YOUR_DISK_ENCRYPTED_PARTITION_UUID> none
EOF
```

Let's build a [Unified Kernel Image](https://wiki.archlinux.org/title/Unified_kernel_image) that will embed the initramfs image (that's the trick, since we can't authenticate the initramfs file itself, we'll build a Unified Kernel Image that contains it and authenticate that).

Edit `/etc/mkinitcpio.d/linux.preset` to look like that:
```
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
ALL_microcode="/boot/intel-ucode.img"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux.img"
default_efi_image="/efi/Linux/archlinux-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"

fallback_image="/boot/initramfs-linux-fallback.img"
fallback_efi_image="/efi/Linux/archlinux-linux-fallback.efi"
fallback_options="-S autodetect --splash /usr/share/systemd/bootctl/splash-arch.bmp"
```

```shell
cat <<EOF > /etc/kernel/cmdline
root=/dev/mapper/root-root resume=/dev/mapper/root-swap rw
EOF

Finally, build your initramfs
```shell
mkinitcpio -P
```

#### Installing & configuring our bootloader (systemd-boot)

```shell
bootctl install
```

There's nothing to configure, systemd-boot should automatically detect our
Unified Kernel Image.

### SecureBoot configuration

At this stage, everything should be all set except one thing: the SecureBoot
configuration to ensure no one tampers with our bootloader, kernel (and other OS
files) and - most important of all - our initramfs.

We'll use [sbctl](https://github.com/Foxboron/sbctl) to configure Secure Boot accordingly, with our own keys, and
that it also authenticates and measures our initramfs.

Following the [up to date instructions on Github](https://github.com/Foxboron/sbctl#key-creation-and-enrollment) is probably the best here.

Just pasting my commands here anyway:

```shell
# First check the status
sbctl status
# Installed:	✘ Sbctl is not installed
# Setup Mode:	✘ Enabled
# Secure Boot:	✘ Disabled

# Then create the keys
sbctl create-keys

# Then enroll the keys in the EFI firmware
# Choose the "safe but sad" microsoft option, see
# https://github.com/Foxboron/sbctl/wiki/FAQ#option-rom
sbctl enroll-keys --microsoft

# Verify that your bootchain isn't signed yet
sbctl verify
# should display all files unsigned, let's sign them and make sure they are
# automatically resigned by a pacman hook when upgraded with -s
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
sbctl sign -s /boot/EFI/Linux/archlinux-linux-fallback.efi
sbctl sign -s /boot/EFI/Linux/archlinux-linux.efi
sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi
sbctl sign -s /boot/vmlinuz-linux
```

Let's exit our chroot, unmount everything and reboot.
```shell
# Exit the chroot

swapoff /dev/mapper/root-swap
umount -R /mnt
vgchange -a n root
crypsetup close cryptoroot
```

At this stage, all our files should be signed, we can reboot. Let's not forget
to reset the SecureBoot mode to "User" in the BIOS.

### (optional): Use your TPM to unlock the root partition

* pros and cons (auto login, or use of a PIN code...)
