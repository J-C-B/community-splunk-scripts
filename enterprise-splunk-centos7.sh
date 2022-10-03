#!/bin/bash

# 30/06/20 John Barnett
# Script created on / for CentOS 7
# Community script to create a Splunk Enterprise node from scratch, use at your own risk
# 

################################################################################################################
## Set password in the script or change it after - default password used by the script is Bz9!SV8VdRiYiman  ####
################################################################################################################

################################################################################################################
## It is designed to run once and assumes a clean system and takes little care as to any existing config    ####
################################################################################################################

# Handy commands for troubleshooting
## tcpdump -i eth0 'port 514'                                                               ## see the flow over a port as events are received (or not)
## /usr/sbin/syslog-ng -F -p /var/run/syslogd.pid                                           ## run syslog-ng and see more errors
## 0 5 * * * /bin/find /var/log/splunklogs/ -type f -name \*.log -mtime +1 -exec rm {} \;   ## add this crontab to delete files off every day at 5am older than 1 day
## multitail -s 2 /var/log/splunklogs/*/*/*.log  /opt/splunk/var/log/splunk/splunkd.log     ## monitor all the files in the splunk dir
## syslog-ng-ctl stats                                                                      ## See the stats for each filter


# Create users
adduser splunk

# Add users to group required
groupadd splunk
usermod -aG splunk splunk

#Show original state
firewall-cmd --list-all
#Splunk ports
firewall-cmd --zone=public --add-port=8000/tcp --permanent # Web UI Port
firewall-cmd --zone=public --add-port=8080/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8088/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8089/tcp --permanent # Managment Port
firewall-cmd --zone=public --add-port=9997/tcp --permanent # Data flow
firewall-cmd --reload
#Check applied
firewall-cmd --list-all

# Deal with THP
# https://docs.splunk.com/Documentation/Splunk/7.2.5/ReleaseNotes/SplunkandTHP

# Check THP status
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# Disable THP at boot
echo "
## Created with JB Splunk Install script by magic
 [Unit]
 Description=Disable Transparent Huge Pages (THP)
 
 [Service]
 Type=simple
 ExecStart=/bin/sh -c \"echo \'never\' > /sys/kernel/mm/transparent_hugepage/enabled && echo \'never\' > /sys/kernel/mm/transparent_hugepage/defrag\"
 
 [Install]
 WantedBy=multi-user.target
" >  /etc/systemd/system/disable-thp.service

sudo systemctl daemon-reload

# Start the disable-thp daemon
systemctl start disable-thp

# Disable THP at startup
systemctl enable disable-thp

# THP now diabled
cat /sys/kernel/mm/transparent_hugepage/enabled
cat /sys/kernel/mm/transparent_hugepage/defrag

# Set file limits

mkdir /etc/systemd/user.conf.d/

echo "
## Created with JB Splunk Install script by magic
## https://docs.splunk.com/Documentation/Splunk/8.0.3/Installation/Systemrequirements#Considerations_regarding_system-wide_resource_limits_on_.2Anix_systems
[Manager]
DefaultLimitFSIZE=-1
DefaultLimitNOFILE=64000
DefaultLimitNPROC=16000
#LimitFSIZE=infinity   # A setting of infinity sets the file size to unlimited.
#LimitDATA=8000000000  #8GB - The maximum RAM you want Splunk Enterprise to allocate in bytes
#TasksMax=16000        #The maximum number of tasks that a service can create. This setting aligns with the user process limit LimitNPROC and the value can be set to match. For example, 16000
" > /etc/systemd/user.conf.d/splunk.conf


#Update package lists
yum update -y

# Install tools
yum install nano wget tcpdump -y

find /usr/share/nano -name '*.nanorc' -printf "include %p\n" > ~/.nanorc

# get the repo
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
rpm -Uvh epel-release-latest-7.noarch.rpm

yum install multitail htop iptraf-ng -y





# add Splunk
cd /opt
mkdir splunk

#wget -O splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.5.1&product=splunk&filename=splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz&wget=true'
#wget -O splunk-7.3.0-657388c7a488-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.3.0&product=splunk&filename=splunk-7.3.0-657388c7a488-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.3&product=splunk&filename=splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.6&product=splunk&filename=splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.2.0&product=splunk&filename=splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.2.3-cd0848707637-Linux-x86_64.tgz 'https://download.splunk.com/products/splunk/releases/8.2.3/linux/splunk-8.2.3-cd0848707637-Linux-x86_64.tgz'
#wget -O splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz "https://download.splunk.com/products/splunk/releases/8.2.5/linux/splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz"
wget -O splunk-9.0.1-82c987350fde-Linux-x86_64.tgz "https://download.splunk.com/products/splunk/releases/9.0.1/linux/splunk-9.0.1-82c987350fde-Linux-x86_64.tgz"


#tar -xf splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz
#tar -xf splunk-7.3.0-657388c7a488-Linux-x86_64.tgz
#tar -xf splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz
#tar -xf splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz
#tar -xf splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz
#tar -xf splunk-8.2.3-cd0848707637-Linux-x86_64.tgz
#tar -xf splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz
tar -xf splunk-9.0.1-82c987350fde-Linux-x86_64.tgz

chown -R splunk:splunk splunk

# Skip Splunk Tour and Change Password Dialog
touch /opt/splunk/etc/.ui_login

# Add listener for splunk TCP 9997 (for UF and other HWF)

mkdir /opt/splunk/etc/apps/9997_listener
mkdir /opt/splunk/etc/apps/9997_listener/local

echo "
## Created with JB Splunk Install script by magic
[splunktcp://9997]
disabled = 0
" > /opt/splunk/etc/apps/9997_listener/local/inputs.conf



# Enable SSL Login for Splunk
echo "Enable WebUI TLS"
 
echo "
## Created with JB Splunk Install script by magic
[settings]
httpport = 8000
enableSplunkWebSSL = true
login_content = Welcome to Splunk, Splunk FTW!
" > /opt/splunk/etc/system/local/web.conf


echo "Starting Splunk - fire it up!! and enabling Splunk to start at boot time with user=splunk "

#echo "Enter auth to enable deployment server"

/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --seed-passwd Bz9!SV8VdRiYiman --answer-yes --auto-ports --no-prompt

chown -R splunk:splunk /opt/splunk

# Add extra users if wanted example

#/opt/splunk/bin/splunk add user user1 -password V6jwLHLqiZdpwXsPQUHc -role admin -auth admin:Bz9!SV8VdRiYiman
#/opt/splunk/bin/splunk add user user2 -password V6jwLHLqiZdpwXsPQUHc -role admin -auth admin:Bz9!SV8VdRiYiman
#/opt/splunk/bin/splunk add user user3 -password V6jwLHLqiZdpwXsPQUHc -role admin -auth admin:Bz9!SV8VdRiYiman
#/opt/splunk/bin/splunk add user user4 -password V6jwLHLqiZdpwXsPQUHc -role admin -auth admin:Bz9!SV8VdRiYiman

/opt/splunk/bin/splunk start


echo "
#################################################################
########## Installation complete
#################################################################
########## for splunk https://<server-ip>:8000
########## user = admin password=the one in the script you set
#################################################################"

curl -k https://localhost:8000


multitail -s 2 /opt/splunk/var/log/splunk/first_install.log  /opt/splunk/var/log/splunk/splunkd.log

## If you are creating a golden image, run this command before locking to prevent duplicate guids etc
# /opt/splunk/bin/splunk clone-prep-clear-config


