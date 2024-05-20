# Part 2 - Host Setup

In this part I will walk through the steps and components to setup a host from scratch with our core infrastructure. This will include: Installing Debian as our OS, installing docker, setting up our docker user, file structure, and networking. I will include a rough ansible playbook in the repository if you want to try to use it. However, it needs a lot of work to properly match the final environment correctly and I still recommend at least reading through the steps below.

# Step 1: Install Debian
For the purposes of this guide I will be using Debian 12.5(Bullseye). I will be writing this guide as I setup everything in a fresh VM, so you can expect the steps to be fairly complete. For most of the Debian install, you should use reasonable defaults.  However, here is a small list of deviations I made:
 - I chose to disable the root account and instead give my account sudo privleges(Which we will provide additional protection for later).
 - I use BTRFS for the root filesystem. This should be straightforward to configure in the installer. I use BTRFS for its logical volume management features, snapshots, and file integrity monitoring/repair(which HAS saved some of my data already...). For my Storage server, I also use it for RAID 1. 
 - I do not install any desktop environment and DO install an SSH Server when prompted.

Once fully installed, we can begin setting up the core infrastructure so that your system can run our docker containers and you can access them remotely. However, at this point you can SSH into your server using the account you created. so you can copy and paste commands as needed(Later we will enforce key-based authentication).

Note many commands in this guide will require root to run. If you don't want to prefix every command with `sudo`, you can run `sudo -i` to get a root terminal. However, please verify every command you enter as some of them can break your installation or data if not careful. Remember, don't run any command you find on the internet without understanding them! Including these!

Before moving on, you should update your apt repos and install a few helpful packages:
```
apt update
apt upgrade
apt install apt-transport-https ca-certificates curl software-properties-common python3-pip virtualenv python3-setuptools git
```

# Step 2: Reorganize BTRFS Volumes
During the install, we setup 1 btrfs volume for the entire root drive. This will work just fine, but for additional configuration, I setup the following structure:
```
\dev\sda1 -- \mnt\btrfs_root -- Root btrfs volume
 sv256 -- \  -- BTRFS Subvolume for root fs
 sv257 -- \home -- BTRFS Subvolume for home directories
 sv258 -- \var\dockers -- BTRFS subvolume for our docker\server folder
 sv259 -- \mnt\btrfs_root\@snapshots -- Stores snapshots
```
Note that `svNNN` refers to a subvolumeid. The actual number is not important as btrfs will create those for us. Understanding the mapping is. 

The flexibility this structure allows us is to do snapshots of the different subvolumes easily, without having to seperate the data. These snapshots can be used as restore points or incremental backups.

Debian 12 will default to installing everything in a subvolume when you perform the install. Earlier versions may not and may install your OS directly to the root btrfs volume(sv0). It is possible to migrate to this fairly easily but is not in the scope of the guide.

However, we still need to finish setting up the rest of it.

The first step is to mount the root volume(remember to change the X to your partition. You can find this by running `lsblk` and looking for which device is mounted to `/`):
```
mkdir -p /mnt/btrfs_root #Create the mount point directory. (-p means create parent directories if needed)
mount /dev/sdaX /mnt/btrfs_root -o defaults,subvolid=5 #Mounts subvol 5(The actual btrfs root) to the folder we just created.
```

Next we will create the home subvolume:
```
btrfs subvolume create /mnt/btrfs_root/@home #Creates our home subvolume as a subvolume of the btrfs_root
cp -R --preserve=all /home/* /mnt/btrfs_root/@home #Copies all files to the new home volume
```
Now we want the home volume to properly map to `/home` so that it is used. We could run a mount command like before, but that wouldn't be repeatable. Instead we will put it in our fstab file which controls the disks that get auto mounted on startup. This way it always is correctly pointed to.

Before we edit the file, we will need two pieces of information: The root UUID, and the subvolume ids.
```
blkid -s UUID -o value /dev/sdaX # This will output the UUID our partition. Copy it somewhere
btrfs sub show /mnt/btrfs_root/@home/ #lists info about the sub volume. Read through it and extract the id.
btrfs sub show /mnt/btrfs_root/@rootfs/
```

Next, we can edit the Fstab file. Open it in your favorite console editor(Nano, VIM, Emacs, etc...). It should look something like this more or less.
```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda1 during installation
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /               btrfs   defaults,subvolid=256 0       0
# swap was on /dev/sda5 during installation
UUID=ad578226-c3bd-4ac7-803a-7bffe3f2ffad none            swap    sw              0       0
/dev/sr0        /media/cdrom0   udf,iso9660 user,noauto     0       0
```
We are going to add two lines, making sure to fill in the appropriate values(Note, the curly braces do not get included in the final output. they are only to help you see what needs to be changed!):
```
UUID={UUID FROM ABOVE} /home btrfs noatime,subvolid={HOME SUBVOLID} 0 0
UUID={UUID FROM ABOVE} /mnt/btrfs_root btrfs ro,subvol=/ 0 0
```
The first line adds the home subvolume mount point and the second adds the btrfs_root. We use two different methods of referring to them. While it should not make a difference whether you use subvol=/@home or subvolid=256 for example, it is less likely to be a problem if it is always refered to by ID. The use of UUID to refer to the disk is important however. While the disk specifiers such as /dev/sdaXX should remain the same from boot to boot, they don't always. UUIDS are guaranteed to remain the same, so we use them. We also made some changes to the options for each of them. @home gets `noatime` which disabled access time recording. This helps speed up the filesystem and reduce needless disk writes. @btrfs_root gets `ro` which means read only since we shouldn't write data directly to the root volume.

Now we are going to change the first line to use our @rootfs subvolid as we did for @home, and update the options to be `noatime` and our file will look like:
```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda1 during installation
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /               btrfs   noatime,subvolid=256 0       0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /home               btrfs   noatime,subvolid=258 0       0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /mnt/btrfs_root               btrfs   ro,subvol=/ 0       0
# swap was on /dev/sda5 during installation
UUID=ad578226-c3bd-4ac7-803a-7bffe3f2ffad none            swap    sw              0       0
/dev/sr0        /media/cdrom0   udf,iso9660 user,noauto     0       0
```

Now we can run `systemctl daemon-reload` and `mount -a` to mount the home directory(The root and btrfs_root won't change since they are already mounted). As long as there are no errors and it mounts succesfully(Which can be verified by reading the output of `mount` or `lsblk`), we can continue with the other subvolumes we need.

Now we need to repeat the same steps from above for our two other subvolumes:
 - @hsc which mounts to /var/dockers(dont forget to create this folder)
 - @snapshots which mounts to /mnt/btrfs_root/@snapshots.
You should be able to follow the same steps as above and just update values accordingly. Your fstab will look like:

```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# systemd generates mount units based on this file, see systemd.mount(5).
# Please run 'systemctl daemon-reload' after making changes here.
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda1 during installation
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /               btrfs   noatime,subvolid=256 0       0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /home               btrfs   noatime,subvolid=258 0       0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /mnt/btrfs_root               btrfs   ro,subvol=/ 0       0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /var/dockers/ btrfs noatime,subvolid=259 0 0
UUID=df5148c2-7f1b-4537-a2a2-17c5c734b116 /mnt/btrfs_root/@snapshots btrfs noatime,subvolid=260 0 0
# swap was on /dev/sda5 during installation
UUID=ad578226-c3bd-4ac7-803a-7bffe3f2ffad none            swap    sw              0       0
/dev/sr0        /media/cdrom0   udf,iso9660 user,noauto     0       0

```

Once those are created and added to the fstab, restart your machine to ensure all the mounts are swapped over.

# Step 3: Install Docker
Now lets install Docker. It is a very easy process for debian and I reccomend following the offical guide here: https://docs.docker.com/engine/install/debian/. 


# Step 4: Setup and Install Zerotier
Zerotier is my personal P2P Mesh VPN of choice. You can use others such as tailscale, but below I will provide brief instructions for setting up Zerotier so you can access your resources outside your home network.

To begin, you will need to create an account and private network. See this guide for details on doing that and joining your regular machine(Not your server): https://docs.zerotier.com/start.

I also have setup a few special configurations on my zerotier network that you may want to replicate(You will see aspects of this mentioned throughout the guide):
- I have setup a manual Ipv4 range for assignment that goes from 192.168.196.130-254. This allows me to set my servers to static IP addresses below that range without worrying about collisions.

Then we can install the client on our server: https://www.zerotier.com/download/. Follow the instructions for linux.

Then to join, just run: `zerotier-cli join NETWORK_ID`, updating it to point to your network ID

Now you should be able to get into your server remotely and securely! You can try it out by using a hotspot for a quick test(However, some cell carriers cause issues with the P2P functionality. Bummer)

# Step 5: Setup the Docker User and directories
Now we are ready to really start using this server. Its secure enough for just you to access it on your local network, but there is a long way to go to really make it secure. The first step in this is the user and directory structure I have created. I will admit at times it has provided more obstacles than necessary, but you can make your own decisions on what holes you poke. 

The first step is to clone our git repo that will store all of our data. Start by forking this repository and then clone so that `/var/dockers/HomeServerConfigs` is the root of repository. While the gitignore and general structure should limit you from pushing sensitive information, it cannot prevent it. Be careful with any changes you push and ensure your git repo is set to private if possible(Or host your own git server...). 

Next, you will find I have a few scripts in the `deployment` folder. You will want to run them in the following order: `setupDockerUser.sh` `setupDirectory.sh` and then `setupPermissions.sh`. You can opt to avoid running setupPermissions for a little bit until you have all your changes made as it will block you from accessing the compose files. The idea there is that you shouldn't be messing with your configuration on your "Production" config. Instead, you should setup a test environment and once the changes are validated, push them to the git repo, where they can be synced down to the server. Alternatively, you can add yourself to the docker runner group that is created and then you can edit the files without having to use sudo.

What these scripts do is:
 - create two users: dockeruser(who owns most of the files) and dockerrunner(who owns the compose files)
 - and one group(in addition to the user groups): dockerfiles(Allows other users to access **most** files in the repo)
 - Creates a bunch of directories and files that arent included in the git repo but are needed for the compose stack to work
 - Sets the permissions on all the files.

If you ever copy files from say your home directory to here, it is important to re-run the permissions script to properly set all the permissions or else you may either increase your vulnerability surface or prevent docker from accessing a file it needs.

You will notice the directory script told you to copy over the secrets. Don't worry about that now, we will do that right before we start up the stack. For now, we move back to more security!

# Step 6: Setup the firewall
Right now, we don't have a firewall that is actually protecting our server. This isn't what we want. Our ideal setup should be that we can only access the server via three ports: 80(HTTP), 443(HTTPS), and 22(SSH) as well as Pings. As long as our home network is secure, we can access those ports via zerotier or via LAN. If you are setting this up on a cloud host, you will probably only want access through zerotier. To do this, we have the following IP Tables script:

```
*filter
:INPUT DROP [447:22468]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -s 192.168.1.0/24 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
-A INPUT -s 10.10.10.0/24 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
-A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j DROP
-A INPUT -p icmp -j ACCEPT
-A INPUT -s 192.168.196.0/24 -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
COMMIT
```
What this does is blocks all connections that are not already established. It then opens port 22 to three networks: 192.168.1.0/24 - My LAN Subnet, 10.10.10.0/24 - My Homelab VLAN, 192.168.196.0/24 - My Zerotier network.
You may be wondering about the other ports. They will get automatically added by Docker. If you wanted to only allow access to them via specific interfaces, that can be setup as well and there are plenty of guides available.

To enable this script, you need to do the following:
1. Install iptables-persistent: `sudo apt install iptables-persistent`
2. Copy the rules above into a file in the /etc/iptables/rules.v4 directory
3. Enabled netfilter: `systemctl enable netfilter-persistent`
4. run `netfilter-persistent reload`
5. Restart Docker: `systemctl restart docker`

What about IPV6?
How to secure that??

# Step 7: Setup SSH / additional security concerns
There are a few remaining "Standard" security features to implement: Only allwoing SSH key based authentication for ssh connections and disabling the root account. 

First we will create or add our ssh key so we can login to the server without our password:

1. If you already have an ssh key you would like to use, skip to step 3.
2. On your client machine(Not the server), generate an ssh-key by running `ssh-keygen -t ed25519` and following the prompts. The `-t ed25519` generates that type of key, which is a newer cipher mechanism that is more secure than standard RSA and should be supported everywhere by now.
3. You will want to copy the contents of your PUBLIC key. Remember NEVER share your private key with anyone! Your public key will be on your client under the `.ssh` folder in your home directory. You can output its contents via `cat ~/.ssh/id_ed25519.pub`. It will have an output similar to:
```
ssh-ed25519 ABUNCHOFRANDOMCHARACTERSGOHERE YOUREMAILORUSERID
```
4. On your server, we need to copy that text into `~/.ssh/authorized_keys`: `mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && echo "YOUR PUBLIC KEY" >> ~/.ssh/authorized_keys`.
5. Finally we need to set permissions on the folder and file: `chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys`

Now logout and try to log back in. It should prompt for your ssh key password instead. As long as that works, we can disable standard password authentication:

1. We need to edit the `/etc/ssh/sshd_config` file using sudo. Once open, find a line that has `PasswordAuthentication (yes or no)`. It may be commented out using a '#'. Uncomment it if needbe and change the line so it is `PasswordAuthetication no`.
2. Now restart the sshd service `sudo serivce sshd restart`

Now noone will be allowed to login using passwords. 

As for disabling root, there are a few ways. However, it should already be disabled. You can try logging in directly on your server, via ssh, or via `su -` to see if you can. In reality, unless you set one in the debian installation, the root account shouldn't even have a password.

One final thing to check is to run `sudo passwd -S root`. As long as this shows the account is Locked(Look for an L), you are good. If not, simply running `sudo passwd -l root` will lock it.


[Previous Part - Prerequisites](./Part1.5-Prerequisites.md) | [Next Part - Core Services](./Part3-ComposeCore.md)