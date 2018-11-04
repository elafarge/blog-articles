3. Setting up the operating system
----------------------------------

### System installation & Chroot

Let's install the target OS in the `/mnt` directory:
```shell
pacstrap /mnt base base-devel
```

##### Generating `fstab`

On Linux, the `/etc/fstab` file describes partitions that should be mounted
automatically after boot. Despite our complex RAID < LUKS < LVM topology,
`genfstab` generates it for us perfectly:
```shell
genfstab -U /mnt >> /mnt/etc/fstab
```

##### Chroot-ing

Let's [chroot](TODO) into our new OS !

```shell
arch-chroot /mnt
```

### System configuration

```shell
# Here, I'm configuring the server timezone to Europe/Paris, choose whatever
# best fits the location of the server, or yours
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

# Set your server's hostname (don't forget to update /etc/hosts as well)
echo "testraid" > /etc/hostname

cat <<EOF > /etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 testraid.example.com testraid
EOF

# Install some programs we'll need later in the setup phase
pacman -S vim zsh docker openssh sudo hdparm git htop

# Set the root password
passwd

# You may want to visudo to allow the wheel group sudo access...
visudo
```

#### Testing the disks

We can run a disk benchmark on the RAW `/dev/sda` device (RAW disk performance)
and another one on `/dev/mapper/root-root`.
```shell
hdparm -tT /dev/sda && hdparm -tT /dev/md/root && hdparm -tT /dev/md/boot && hdparm -tT /dev/mapper/root-root
```

On our machine:
```shell
/dev/sda:
 Timing cached reads:   33314 MB in  1.99 seconds = 16730.16 MB/sec
 Timing buffered disk reads: 1258 MB in  3.00 seconds = 418.69 MB/sec

/dev/mapper/root-root:
 Timing cached reads:   31712 MB in  1.99 seconds = 15919.42 MB/sec
 Timing buffered disk reads: 572 MB in  3.01 seconds = 190.11 MB/sec
```

That's very interesting: we can observe that RAID1 performs slighly better than
the RAW disks, and that RAID5 doubles the performance :)

On the shadier side of things, LUKS encryption (with AES128, which should be the
default) lowers the performance a bit below what it was on RAW disks. Encryption
isn't **that** cheap ;-)

If performance is too poor, consider using a different cipher for LUKS
encryption. I initially started with AES256 i/o the default but performance was
terrible, which made me go back to cryptsetup's default.

#### Boot configuration

Given our advanced disk setup, boot configuration is going to be the hardest
part here. Let's sum up what needs to be done: *enabling SSH in our initramfs
so that the encryption key can be entered in the server*, *embedding kernel
hooks for dm (RAID), luks (encryption), and lvm* into that same initramfs.

Note: the *initramfs* is a program, launched by our bootloader, in charge of
starting the Linux kernel and the root process (`systemd` on ArchLinux), which
will in turn start all other daemons running on our server.

##### `mkinitcpio`

We'll first need to install kernel hooks enabling SSH in early boot so that we
can remotely connect to our server and input the encryption key we set earlier.

That requires some unofficial [packages from the Arch User
Repository](https://wiki.archlinux.org/index.php/Dm-crypt/Specialties#Remote_unlocking_of_the_root_.28or_other.29_partition).
We'll use
[pakku](https://wiki.archlinux.org/index.php/AUR_helpers#Pacman_wrappers) to
manage them. That also means we'll need to "sandbox" ourselves into non-root
user accounts to build them.
```shell
useradd -m -g users -G wheel -s /bin/zsh yourname
```
Also, make sure to grant the `wheel` group sudo access with `visudo`.

Ok, let's now build and install these packages from the AUR.
```shell

# First, install pakku, an AUR package installer
su yourname
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
exit
```

Let's enable the Kernel hooks provided by these packages  in the `initramfs`: `mdadm_udev`,
`keyboard`, `keymap`, `netconf`, `dropbear`, `encryptssh`, `lvm2`, for that, edit the `HOOKS` variable in
`/etc/mkinitcpio.conf`:

```
HOOKS=(base udev autodetect modconf keyboard keymap block mdadm_udev netconf dropbear encryptssh lvm2 filesystems fsck)
```

We'll now need to configure the hooks:

```shell
# Put the SSH key you want to use to connect to your server to unlock it
mkdir /root/.ssh
echo -n "YOUR_PUBLIC_SSH_KEY" > /etc/dropbear/root_key
chmod 600 /etc/dropbear/root_key
```

Then, you need to figure out which driver to enable for your network card to be
usable by the kernel at boot time:

```shell
lspci -k

# There should be one/multiple (depending on how many network interfaces are
# enabled on your machine) entries like this one.
01:00.1 Ethernet controller: Intel Corporation I350 Gigabit Network Connection (rev 01)
	Subsystem: Super Micro Computer Inc Dual Port i350 GbE MicroLP [AOC-CGP-i2]
	Kernel driver in use: igb
```

Here `igb` is the Kernel module to be loaded at boot time, add it to your
`mkinitcpio.conf`:
```
MODULES=(igb)
```

Finally, build your initramfs
```shell
mkinitcpio -p linux
```

#### Bootloader configuration

We'll go for GRUB !
```shell
sudo pacman -S grub

# Install it on the 3 disks
grub-install --target=i386-pc /dev/sda
grub-install --target=i386-pc /dev/sdb
grub-install --target=i386-pc /dev/sdc
```

Then, edit the `/etc/default/grub` file and make sure these variables are set:
```
# nomodeset is necessary on my machine, but might not be on yours...
GRUB_CMDLINE_LINUX_DEFAULT="quiet nomodeset"

# Let's enable the network interfaces and provide the UUID of the encrypted
# RAID array to the Linux command line launched by the bootloader.
# Run
#   lsblk -o NAME:UUID
# to figure it out
GRUB_CMDLINE_LINUX="ip=ip=:::::eth0:dhcp:ip=:::::eth1:dhcp cryptdevice=UUID=<the-uuid-of-your-encrypted-raid-array>:cryptoroot root=/dev/mapper/root-root rw"
```

And let's install GRUB !
```shell
grub-mkconfig -o /boot/grub/grub.cfg
```

#### Processor microcode

For machines running on Intel processors, you can additionally install Intel's
microcode with `pacman -S intel-ucode`

#### Time to reboot !

You'll be able to SSH onto your machine when it starts, enter the passphrase and
decrypt the disks.

[Step 4: setting up and iptables firewall](./04_iptables.md)
