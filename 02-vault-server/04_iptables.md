Step 4 - Setting up an `iptables` firewall
==========================================

#### Basic security measures

Our machine's disks are encrypted, which basically protects us from someone
unmounting and reading the content of our disks. But... in the current state,
our it is exposed to the entire Internet. This article doesn't focus on network
security, however, we'll go through the basics real quick.

##### Configure the SSH daemon accordingly

One of the first thing to do is making sure that password-based auth is disabled
for your SSH connections. An SSH key should always be preferred.

Another common setting is to change the port SSH listens on to something
different than 22 or 2222. Bots commonly scan these ports and try to brute
force your SSH connection, flooding your SSH audit logs (run `journalctl -xef -u
sshd` to retrieve them).

Speaking of which, maybe you'll also be willing to increase the verbosity of
these logs to be able to finely analyse what's been done on your server through
SSH.

Let's `vim /etc/ssh/sshd_config`:

```
# Set a port different than 22 or 2222
Port 27667

# Listen on all interfaces (if a second network interface is wired to your local
# network and you're using a bastion to jump on this network, you may want to
# restrict SSH connection to that interface)
ListenAddress 0.0.0.0
ListenAddress ::

# Verbose sshd logs
LogLevel VERBOSE

# Disable password authentication
PasswordAuthentication no
```

Tons of other options exist, the `man` pages are your friend.
Also, if you feel a bit unfamiliar with SSH and want to learn more about
amazings things it can do. You'll love [this video](https://vimeo.com/54505525).

##### Forbid all incoming traffic with `iptables`

There still on **huge** security threat on our server: all ports are opened. Any
application listening on a any TCP port to the entire web is exposed. Hopefully,
that's just gonna be `sshd`. You can check that with `ss -atn`.

However, it is likely that you'll create processes that will listen on a given
port, and it is also likely that some of these services will listen *on all
interfaces* by default.

Even if you don't think you'll deploy such apps, taking preventive measures is
essential. Lots of programs expose a daemon over a TCP ports (auto-completers,
debuggers...).

Let's forbid all non-SSH traffic for now. As you deploy new apps that you really
want to expose to the entire world, you'll add new `iptables` rules. Here's the
how-to:

* First of all, create the iptables.rules file
```shell
vim /etc/iptables/iptables.rules
```

* Then paste a basic set of rules to allow any kind of outgoing traffic and
incoming pings and SSH traffic:

```
# Firewall Rules live under the "*filter" section
*filter

# Deny all incoming connections by default
:INPUT DROP [27:2678]

# Accept all FORWARD / outbound traffic when no rule is matched
# TODO: DROP FORWARD traffic by default ?
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [160:34292]
:LOG_DROP - [0:0]

# Allow incoming connections from localhost
-A INPUT -i lo -j ACCEPT
# -A OUTPUT -o lo -j ACCEPT
# -A FORWARD -o lo -j ACCEPT

# Allow all incoming ICMP traffic (ping commands)
-A INPUT -p icmp -j ACCEPT

# Allow external servers to send their replies on connection initiated by
# outbound traffic
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow incoming connections on chosen SSH port
-A INPUT -p tcp -m state --state NEW,ESTABLISHED -m tcp --dport 6969 -j ACCEPT

COMMIT
```

* Then enable and start the iptables service
```shell
systemctl start iptables.service
systemctl enable iptables.service
```

You can use `nmap` to scan for open ports on your machine.
```shell
# From your local computer
sudo nmap -sS -sU <YOUR_SERVER_IP>
```
