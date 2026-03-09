#!/bin/bash

# 14/03/21 John Barnett
# Script created on / for CentOS 7
# Community script to prep the OS for a Splunk Enterprise node from scratch, use at your own risk
# It does not install any Splunk componentents, it just applies best prectices to the OS

################################################################################################################
## It is designed to run once and assumes a clean system and takes little care as to any existing config    ####
################################################################################################################

# Create users
adduser splunk

# Add users to group required
groupadd splunk
usermod -aG splunk splunk

#Show original state
firewall-cmd --list-all
#Splunk ports
#firewall-cmd --zone=public --add-port=8000/tcp --permanent # Web UI Port
#firewall-cmd --zone=public --add-port=8080/tcp --permanent # HEC port
#firewall-cmd --zone=public --add-port=8088/tcp --permanent # HEC port
#firewall-cmd --zone=public --add-port=8089/tcp --permanent # Managment Port
#firewall-cmd --zone=public --add-port=9997/tcp --permanent # Data flow
#firewall-cmd --reload
#Check applied
#firewall-cmd --list-all

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

# /opt/splunk/bin/splunk enable boot-start ####### -user root --accept-license

# chown -R splunk:splunk /opt/splunk



