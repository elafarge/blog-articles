Step 1 - Setting up the installation environment
------------------------------------------------

### Get a server (with VLANs enabled if you plan on adding more servers later)

 - Procedure with online.net: TODO

### Boot an ArchLinux installation medium
 - Boot an archlinux installation ISO on your machine

 - Get a shell on it leveraging iDRAC/KVM (if not available it's also possible
   to create a temporarary OS installation using your provider's setup tools
   that will be used to perform the installation on a small part of the disk
   (let's say, the first 4GiBs) and then us this OS to bootstrap our layout,
   atop the remaining disk space.

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

#### Going further
 * [Arch Wiki regarding SSH](https://wiki.archlinux.org/index.php/Secure_Shell)
 * `man ssh` (client) & `man sshd` (server)

[Step 2: setting up the filesystem](./02_filesystem_setup.md)
