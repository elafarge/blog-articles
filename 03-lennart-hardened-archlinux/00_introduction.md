The strange state of Authenticated Boot and Disk Encryption on Linux
====================================================================

In September 2021, Lennart Poetterring (known for systemd, among other things)
wrote [an article about the strange state of disk security on
Linux](http://0pointer.net/blog/authenticated-boot-and-disk-encryption-on-linux.html),
raising serious security concerns around the way most distributions handle boot
authentication and disk encryption.

Without getting into too much detail (Poettering's article does if you're
interested), disk encryption aims at protecting the disks' data with a key (or
passphrase) encrypting the hard drive's content.

However, the bootloader and /boot partition are usually left unencrypted.
The former can be protected by secure boot (the proper term is "authenticated")
so that the system won't boot if a hacker tries to inject malicious code in the
bootloader, as well as extra bootloader code on the /boot partition and the
kernel (usually /boot/vmlinuz-linux) or the CPU microcode *but not the initrd
(/boot/initramfs-linux.img on archlinux)*.

Since the initrd is the program that usually asks for your password, an attacker
(with physical access to your laptop) could easily patch it to retrieve your
secret key, so ideally you'd want it to be authenticated as well.

## How to make my ArchLinux installation initrd-tampering proof then ?

In this article, we'll install archlinux, secure the bootloader and /boot
partition - *including the initramfs* - with SecureBoot and encrypt the root
partition ([LVM on LUKS setup](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system#LVM_on_LUKS)).

This installation is opinionated: it fits well with a single-user laptop. It can
easily be adapted to different scenarios.

### Alternative setup: encrypting the /boot partition

GRUB supports [encrypting the /boot
partition](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system#Encrypted_boot_partition_(GRUB)).

As long as SecureBoot prevents attackers from tampering with the bootloader to
steal your encryption key or passphrase, this solution provides the same level
of security.

However, we're not going to encrypt the /boot partition because
- not everybody wants to use GRUB
- it's going to get better very soon but GRUB has limited compatibility with
  LUKS 2
- from my personal experience, it makes the boot process pretty slow on my
  previous setup (but I may just have ill-configured something)

## References
- Poettering's article: http://0pointer.net/blog/authenticated-boot-and-disk-encryption-on-linux.html
- Arch Wiki on disk encryption: https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system
- Reddit Article: https://www.reddit.com/r/archlinux/comments/sylgvj/any_insight_when_if_ever_will_poetterings/
