# Part 5  - Updates and Monitoring


Now our system is setup to run the services we want. They will be securely accessible from our zerotier network or LAN. Lets take a break from docker to focus on keeping our systems up to date and allow for email notifications.

# Setting up email

## The external service
In order for the server to autonomosly send emails, you will need to set up an email provider. I use sendgrid, but there are many options. Simply create an account and follow their instructions to setup the domain and other pre-requisites.

## The system setup
We need to setup a few things on our host system to allow our email service to be used for notifications. 

1. Install the required packages: `apt install bsd-mailx msmtp-mta msmtp mailutils libasl0 cyrus-common sasl2-bin`
2. Copy over the config files. I have templates in the deployment/mail folder.
   1. msmtprc -> /etc/msmtprc
   2. sendmail.mc -> /etc/mail/sendmail.mc
   3. usr.bin.msmtp -> /etc/apparmor.d/usr.bin.msmtp
   4. local-usr.bin.msmtp ->/etc/apparmor.d/local-usr.bin.msmtp
   5. access -> /etc/mail/access
   6. aliases -> /etc/aliases
3. Make sure the msmtp log exists: `touch /var/log/msmtp && chmod 777 /var/log/msmtp`
4. Reload apparmor
5. rebuild the mail databases
   1. `cd /etc/mail && make`
   2. `systemctl restart sendmail`
   3. `makemap has /etc/mail/access.db < /etc/mail/access`

Now we can test that it works: `echo "Hello world" | mail -s "Test" YOUR_ACTUAL_EMAIL` which will send a message to your email address from the address you configured with sendgrid and in the mail files




# Setting up unattended-upgrade
It is important that our server stay up to date with the latest packages and security updates. However, it is very easy to setup.
1. Install the required packages: `apt install unatennded-upgrades`
2. Configure it: Copy the 50unattended-upgrades file to /etc/apt/apt.conf.d/50unattended-upgrades
   1. Make sure to update it to your values
3. Test: `sudo unattended-upgrade`
   1. You should recieve an email summary!


# Auto syncing updates to our docker setup
Here we will setup a cron to automatically sync our docker setup from the git repo.

Add the following to your system cron by adding a file to /etc/cron.d/: 
```
0 3    * * *   dockerrunner    /var/dockers/HomeServerConfigs/compose/scripts/sync.sh
```

# Auto run btrfs scans
There are two main ways to automate btrfs checks: using the btrfsmaintenance toolset: https://github.com/kdave/btrfsmaintenance or using custom scripts.

I did not like the options presented by btrfsmaintenance, so I found a solution on Reddit: https://www.reddit.com/r/btrfs/comments/ghayaw/monitoring_script_with_alert_sent_by_email/

I have modified the script slightly and have included it in the deployment folder. 

To actually make it run periodically, you need to simply copy the btrfs-monthly and btrfs-hourly scripts into /etc/cron.monthly/ and /etc/cron.hourly accordingly. Then copy the btrfsCheck.sh into /root/scripts/

# Smartmontools
Almost all disk drives have a feature known as S.M.A.R.T which allows for disks to report their internal statuses and for scans to be performed to identify failing disks before they fail. 

To set this up, first install smartmontools: `sudo apt install smartmontools`

I used [this ansible role](https://github.com/stuvusIT/smartd) to setup the actual configuration; however, all it does is create a single configuration file and enable the service:

/etc/smartd.conf
```
DEVICESCAN -n standby,15,q -S on -H -l error \
 -l xerror \
 -l selftest \
 -l offlinests \
 -l scterc,0,0 \
 -e lookahead,on \
 -s (S/../.././02) \
 -m YOUR_EMAIL \
 -M diminishing \
 -f -p -C 197+ -U 198+ -W 10,45,50
```
Please read the documentation to understand


and enable: `sudo systemctl enable smartd`


# Snapshots!
A very useful ability is for btrfs to automatically perform a snapshot before any actions are performed via apt.

1. Install btrbk `sudo apt install btrbk`
2. Copy the config `cp deployment/btrbk/btrbk /etc/btrbk/btrbk.conf`
3. Setup the apt triggers: `cp deployment/btrbk/70btrbk /etc/apt/apt.conf.d/70btrbk`
4. Auto snapshot - check schedule: `btrbk run -n -S`
5. Configure the cronjob: /etc/cron.hourly/btrbk:
```
#!/bin/sh
exec /usr/bin/btrbk -q run
```

[Previous Part - Managment Services](./Part4-ComposeManagement.md) | [Next Part - Your Apps!](./Part6-Software.md)