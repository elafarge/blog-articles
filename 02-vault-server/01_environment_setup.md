Step 1 - Setting up the installation environment
------------------------------------------------

The goal of this step is to run an Archlinux installation ISO on your server.
This highly depends on your provider, basically what we'll need is:
 * an iDARC card supporting KVM over IP
 * an Archlinux installation ISO provided by your provider, or [netboot](https://netboot.xyz/faq/)

### Get a server (with VLANs enabled if you plan on adding more servers later)

 - We'll describe the steps for a server at online.net. First thing to do is
   [order a server there](https://www.online.net/en/dedicated-server) if you
   don't have one yet.
   You may be required to install a distribution on your server (or, for
   online.net simply choose "custom installation").

### Boot an ArchLinux installation medium

In this step, we'll assume your server has an iDRAC/KVM card. Which basically
means you can access a virtual screen and keyboard to setup your machine.

We'll need to:
 - leverage iDRAC/KVM to mount an ArchLinux installation ISO on your machine
 - then have your machin  boot onto it
 - still with iDRAC/KVM, get a shell on this installation OS

The procedure for online.net is described in [their
documentation](https://documentation.online.net/en/dedicated-server/operating-system/custom-install/install-from-kvm-dedibox-xc).
Make sure you're using the latest ArchLinux ISO they're providing you with.

NOTE: if using KVM over IP or a similar turn key solution isn't possible, or if your provider charges you for KVM over IP, another solution exists: you can run a rescue OS (providers usually make that possible) on which you launch your installation ISO in a QEMU VM. The protocol is described [in this article](https://trick77.com/how-to-set-up-virtual-kvm-vnc-console-ovh-server/).

NOTE2: if you have physical access to your machine, things are much simpler.
Simply follow the standard procedure for [creating a bootable ArchLinux USB
stick](https://wiki.archlinux.org/index.php/Installing_Arch_Linux_on_a_USB_key)
and plug it into your server along with a screen and keyboard.

#### A note for the utterly paranoid administrator

Of course, you have no control over the ISO you just booted. As far as we're
concerned, it might use a shell or an OpenSSH daemon with keyloggers enabled. Of
course, analyzing network traffic is still possible, making sure that the SSH
logs don't leak the encryption passphrase you input later as well. If you're
worried about that kind of things, then the best option you have is to use a
server you have physical access to. Installing a tiny, encrypted ArchLinux
distribution at the beginning of your disk and setting up the target OS from
there is also possible.

For simplicity's sake, we won't describe this procedure but keep in mind that
it's totally possible and can be worth the few Gigabytes you'll loose on every
disk (for the encrypted OS used to install the final OS) if you can't trust your
provider.

### Enable SSH access on the installation environment (optional)

You probably will prefer carrying on with the installation using SSH rather that
the in-browser (or worse, JNLP) terminal. Set up **key-based** SSH auth and
connect to the installation OS on your server. We'll assume your KVM console
doesn't support copy/pasting.

On the server:
```shell
# Edit the SSHD config and make sure the "PasswordAuthentication" field is set
# to "yes", as well as "PermitRootLogin"
vim /etc/ssh/sshd_config

# Now, generate a password for your root user (it's suggested that you use a
one-time password since there is no guarantee that the installation medium won't
leak this password)
passwd

# Start the OpenSSH daemon on your server
systemctl start sshd
```

On your machine:
```shell
# (Optional) if you're an adept of the "one different SSH key per server",
# generate a new key.
ssh-keygen -t rsa -b 4096

# Connect to the server via SSH with a password
ssh root@<YOUR_SERVERS_IP>
```

On your server:
```shell
# Paste your Public SSH key in the list of authorized keys
mkdir /root/.ssh
echo -n "your_public_key" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Disable password-based SSH auth
vim /etc/ssh/sshd_config
# Make sure that the "PasswordAuthentication" field is set to "no"

# Restart the OpenSSH daemon
systemctl restart sshd
```

Make sure that you can SSH to your machine using your private key. If so,
your'll finally be able to start setting up the machine from the comfort of your
favorite terminal emulator, you can close the KVM/iDRAC window :)

Provided that the OpenSSH and LUKS binaries on the installation medium you have
are safe the network encryption provided by OpenSSH provides you the security
gurantees you need. No one will be able to record your target encryption
passphrase.

#### Going further
 * [Arch Wiki regarding SSH](https://wiki.archlinux.org/index.php/Secure_Shell)
 * `man ssh` (client) & `man sshd` (server)

[Step 2: setting up the filesystem](./02_filesystem_setup.md)
