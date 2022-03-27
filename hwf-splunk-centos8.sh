#!/bin/bash

# 11/05/20 John Barnett
# Script created on / for CentOS 8 ONLY
# Community script to create a Splunk syslog-ng heavy forwarder from scratch, use at your own risk
# 
# wget https://gitlab.com/J-C-B/community-splunk-build-scripts/-/raw/master/hwf-splunk-centos8.sh

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


# add crontab to delete older log files automatically (optional)
#crontab -l | { cat; echo "0 5 * * * /bin/find /var/log/splunklogs/ -type f -name \*.log -mtime +1 -exec rm {} \;"; } | crontab -

# Create users
adduser syslog-ng
adduser splunk

# Add users to group required
groupadd splunk
usermod -aG splunk syslog-ng
usermod -aG splunk splunk

mkdir /var/log/splunklogs
mkdir /var/log/splunklogs/catch_all/
mkdir /var/log/splunklogs/cisco/
mkdir /var/log/splunklogs/cisco/asa/
mkdir /var/log/splunklogs/paloalto/
mkdir /var/log/splunklogs/fortinet/

chown -R syslog-ng:splunk /var/log/splunklogs



#Show original state
firewall-cmd --list-all
#Splunk ports
firewall-cmd --zone=public --add-port=8000/tcp --permanent # Web UI Port
firewall-cmd --zone=public --add-port=8080/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8088/tcp --permanent # HEC port
firewall-cmd --zone=public --add-port=8089/tcp --permanent # Managment Port
firewall-cmd --zone=public --add-port=9997/tcp --permanent # Data flow
#Syslog listeners
firewall-cmd --zone=public --add-port=514/tcp --permanent
#firewall-cmd --zone=public --add-port=1514/tcp --permanent
#firewall-cmd --zone=public --add-port=1515/tcp --permanent
#firewall-cmd --zone=public --add-port=1516/tcp --permanent
#firewall-cmd --zone=public --add-port=1517/tcp --permanent
#firewall-cmd --zone=public --add-port=1518/tcp --permanent
#firewall-cmd --zone=public --add-port=1514/udp --permanent
firewall-cmd --zone=public --add-port=514/udp --permanent
#reload the setting to take effect
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


# THP now disabled
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


# remove default sysloger
dnf erase rsyslog -y

#Update package lists
dnf update -y

# Install tools
dnf install nano  wget tcpdump -y

find /usr/share/nano -name '*.nanorc' -printf "include %p\n" > ~/.nanorc

# get the repo
dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
dnf config-manager --set-enabled PowerTools

dnf install syslog-ng multitail htop iptraf-ng -y


# Add syslog listener
echo "
## Created with JB Splunk Install script by magic
# syslog-ng configuration file.
# https://www.splunk.com/blog/2016/03/11/using-syslog-ng-with-splunk.html
#
@version: 3.5
    options {
        chain_hostnames(no);
        create_dirs (yes);
        dir_perm(0755);
        dns_cache(yes);
        keep_hostname(yes);
        log_fifo_size(2048);
        log_msg_size(8192);
        perm(0644);
        time_reopen (10);
        use_dns(yes);
        use_fqdn(yes);
        };
    source s_network {
        syslog(transport(udp) port(514));
        };


#Destinations
    destination d_cisco_asa { file(\"/var/log/splunklogs/cisco/asa/\$HOST/\$YEAR-\$MONTH-\$DAY-cisco-asa.log\" owner(\"splunk\") group(\"splunk\") perm(0775) create_dirs(yes)); };
    destination d_fortinet { file(\"/var/log/splunklogs/fortinet/\$HOST/\$YEAR-\$MONTH-\$DAY-fortigate.log\" owner(\"splunk\") group(\"splunk\") perm(0775) create_dirs(yes)); };
    destination d_juniper { file(\"/var/log/splunklogs/juniper/junos/\$HOST/\$YEAR-\$MONTH-\$DAY-juniper-junos.log\" owner(\"splunk\") group(\"splunk\") perm(0775) create_dirs(yes)); };
    destination d_palo_alto { file(\"/var/log/splunklogs/paloalto/\$HOST/\$YEAR-\$MONTH-\$DAY-palo.log\" owner(\"splunk\") group(\"splunk\") perm(0775) create_dirs(yes)); };
    destination d_all { file(\"/var/log/splunklogs/catch_all/\$HOST/\$YEAR-\$MONTH-\$DAY-catch_all.log\" owner(\"splunk\") group(\"splunk\") perm(0775) create_dirs(yes)); };



# Filters
    filter f_cisco_asa { match(\"%ASA\" value(\"PROGRAM\")) or match(\"%ASA\" value(\"MESSAGE\")); };
    filter f_fortinet { match(\"devid=FG\" value(\"PROGRAM\")) or host(\"msu\") or match(\"devid=FG\" value(\"MESSAGE\")); };
    filter f_juniper { match(\"junos\" value(\"PROGRAM\")) or host(\"Internet\") or host(\"150.1.156.30\") or host(\"150.1.128.10\") or match(\"junos\" value(\"MESSAGE\")) or match(\"RT_FLOW:\" value(\"MESSAGE\")); };
    filter f_palo_alto { match(\"009401000570\" value(\"PROGRAM\")) or match(\"009401000570\" value(\"MESSAGE\")); };
    filter f_all { not (
    filter(f_cisco_asa) or
    filter(f_fortinet) or
    filter(f_juniper) or
    filter(f_palo_alto)
    );
};
# Log
    log { source(s_network); filter(f_cisco_asa); destination(d_cisco_asa); };
    log { source(s_network); filter(f_fortinet); destination(d_fortinet); };
    log { source(s_network); filter(f_juniper); destination(d_juniper); };
    log { source(s_network); filter(f_palo_alto); destination(d_palo_alto); };
    log { source(s_network); filter(f_all); destination(d_all); };

" >  /etc/syslog-ng/conf.d/listeners_4_splunk.conf


#enable syslog-ng
systemctl enable syslog-ng
systemctl start syslog-ng

# add Splunk
cd /opt
mkdir splunk

#wget -O splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.2.5.1&product=splunk&filename=splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz&wget=true'
#wget -O splunk-7.3.0-657388c7a488-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=7.3.0&product=splunk&filename=splunk-7.3.0-657388c7a488-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.3&product=splunk&filename=splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.0.6&product=splunk&filename=splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz 'https://www.splunk.com/bin/splunk/DownloadActivityServlet?architecture=x86_64&platform=linux&version=8.2.0&product=splunk&filename=splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz&wget=true'
#wget -O splunk-8.2.3-cd0848707637-Linux-x86_64.tgz 'https://download.splunk.com/products/splunk/releases/8.2.3/linux/splunk-8.2.3-cd0848707637-Linux-x86_64.tgz'
wget -O splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz "https://download.splunk.com/products/splunk/releases/8.2.5/linux/splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz"



#tar -xf splunk-7.2.5.1-962d9a8e1586-Linux-x86_64.tgz
#tar -xf splunk-7.3.0-657388c7a488-Linux-x86_64.tgz
#tar -xf splunk-8.0.3-a6754d8441bf-Linux-x86_64.tgz
#tar -xf splunk-8.0.6-152fb4b2bb96-Linux-x86_64.tgz
#tar -xf splunk-8.2.0-e053ef3c985f-Linux-x86_64.tgz
#tar -xf splunk-8.2.3-cd0848707637-Linux-x86_64.tgz
tar -xf splunk-8.2.5-77015bc7a462-Linux-x86_64.tgz


chown -R splunk:splunk splunk

# Skip Splunk Tour and Change Password dialogue
touch /opt/splunk/etc/.ui_login

# Add listener for splunk TCP 9997 (for UF and other HWF)

mkdir /opt/splunk/etc/apps/9997_listener
mkdir /opt/splunk/etc/apps/9997_listener/local

echo "
## Created with JB Splunk Install script by magic
[splunktcp://9997]
disabled = 0
" > /opt/splunk/etc/apps/9997_listener/local/inputs.conf

# Add file monitors for syslog-ng

mkdir /opt/splunk/etc/apps/syslogng_monitors
mkdir /opt/splunk/etc/apps/syslogng_monitors/local

echo "
## Created with JB Splunk Install script by magic

[pan]
homePath   = \$SPLUNK_DB/\$_index_name/db
coldPath   = \$SPLUNK_DB/\$_index_name/colddb
thawedPath = \$SPLUNK_DB/pan/thaweddb

[cisco]
homePath   = \$SPLUNK_DB/\$_index_name/db
coldPath   = \$SPLUNK_DB/\$_index_name/colddb
thawedPath = \$SPLUNK_DB/cisco/thaweddb

[fortinet]
homePath   = \$SPLUNK_DB/\$_index_name/db
coldPath   = \$SPLUNK_DB/\$_index_name/colddb
thawedPath = \$SPLUNK_DB/fortinet/thaweddb

[juniper]
homePath   = \$SPLUNK_DB/\$_index_name/db
coldPath   = \$SPLUNK_DB/\$_index_name/colddb
thawedPath = \$SPLUNK_DB/juniper/thaweddb


" > /opt/splunk/etc/apps/syslogng_monitors/local/indexes.conf


echo "
## Created with JB Splunk Install script by magic
# Palo
[monitor:///var/log/splunklogs/paloalto/*/*.log]
sourcetype = pan:log
index = pan
disabled = false
host_segment = 5

# Cisco ASA
[monitor:///var/log/splunklogs/cisco/asa/*/*.log]
sourcetype = cisco:asa
index = cisco
disabled = true
host_segment = 6

# Fortinet
[monitor:///var/log/splunklogs/fortinet/*/*fortigate.log]
sourcetype = fgt_log
index = fortinet
disabled = false
host_segment = 5

# Juniper
[monitor:///var/log/splunklogs/juniper/junos/*/*.log]
sourcetype = juniper
index = juniper
disabled = false
host_segment = 6
" > /opt/splunk/etc/apps/syslogng_monitors/local/inputs.conf

########################## Adding the TAs
cd /opt

wget https://johnb-bucket-pub.s3-ap-southeast-2.amazonaws.com/dc/dc_apps.tar

tar -xf dc_apps.tar

cd /opt/dc_apps

for f in *.tar.gz; do tar -zxvf "$f" -C /opt/splunk/etc/apps/; done

for f in *.tar; do tar -xvf "$f" -C /opt/splunk/etc/apps/; done

for f in *.tgz; do tar -xvf "$f" -C /opt/splunk/etc/apps/; done

########################## Adding the deployment apps
cd /opt

wget https://johnb-bucket-pub.s3-ap-southeast-2.amazonaws.com/dc/dc_dep_apps.tar

tar -xf dc_dep_apps.tar

cd /opt/dc_dep_apps

for f in *.tar.gz; do tar -zxvf "$f" -C /opt/splunk/etc/deployment-apps/; done

for f in *.tgz; do tar -xvf "$f" -C /opt/splunk/etc/deployment-apps/; done

for f in *.tar; do tar -xvf "$f" -C /opt/splunk/etc/deployment-apps/; done


# Enable SSL Login for Splunk
echo "Enable WebUI TLS"
 
echo "
[settings]
httpport = 8000
enableSplunkWebSSL = true
login_content = Welcome to your Splunk hwf, Splunk FTW!
" > /opt/splunk/etc/system/local/web.conf

chown -R splunk:splunk /opt/splunk

echo "Starting Splunk - fire it up!! and enabling Splunk to start at boot time with user=splunk "

/opt/splunk/bin/splunk enable boot-start -user splunk --accept-license --seed-passwd Bz9!SV8VdRiYiman --answer-yes --auto-ports --no-prompt

/opt/splunk/bin/splunk start

echo "
#################################################################
########## Installation complete
#################################################################
########## for splunk https://<server-ip>:8000
########## user = admin password=the one in the script you set
#################################################################"

curl -k https://localhost:8000

# command below should trigger syslog-ng to log an event for Splunk to collect
logger -n 127.0.0.1 -P 514 " **** cisco test event **** Apr 07 01:59:19: %ASA-4-338002: Dynamic Filter monitored blacklisted TCP traffic from CyberRange-Dev-Red:224.10.25.172/56290 (224.10.25.172/56290) to Backbone:224.10.25.1/80 (224.10.25.1/80), destination 224.10.1.172 resolved from dynamic list: 224.10.1.172, threat-level: very-high, category: Malware"
logger -n 127.0.0.1 -P 514 " **** catchall test event **** Apr 07 01:59:19: **** catchall: **** test event **** "
logger -n 127.0.0.1 -P 514 " **** juniper test event **** 1 2019-04-08T20:17:19.120+12:00 Internet RT_FLOW - RT_FLOW_SESSION_CREATE [junos@2636.1.1.1.2.40 source-address="10.176.101.11" source-port="59627" destination-address="192.168.10.25" destination-port="8400" service-name="None" nat-source-address="10.176.11.11" nat-source-port="59627" nat-destination-address="192.168.10.25" nat-destination-port="8400" src-nat-rule-name="None" dst-nat-rule-name="None" protocol-id="6" policy-name="248" source-zone-name="Trust" destination-zone-name="DMZ_2" session-id-32="138471" username="N/A" roles="N/A" packet-incoming-interface="reth0.0"] session created 10.176.101.11/59627->192.168.10.25/8400 None 10.176.101.11/59627->192.168.10.25/8400 None None 6 248 Trust DMZ_2_A2 138471 N/A(N/A) reth0.0"
logger -n 127.0.0.1 -P 514 " **** fortinet test event **** date=2019-04-08,time=20:33:26,devname=3kUnitB,devid=FG3K2C31,logid=0315012544,type=utm,subtype=webfilter,eventtype=urlfilter,level=warning,vd="CCorp",urlfilteridx=3,urlfilterlist="Microsoft-Wildcard",policyid=4303,sessionid=3097985850,user="",srcip=10.250.35.24,srcport=54653,srcintf="V1215-EPZP",dstip=54.214.227.245,dstport=443,dstintf="root",proto=6,service=HTTPS,hostname="aztec.brightmail.com",profile="Microsoft-Wildcard",action=blocked,reqtype=direct,url="/",sentbyte=346,rcvdbyte=3523,direction=outgoing,msg="URL was blocked because it is in the URL filter list",crscore=30,crlevel=high"


multitail -s 2 /var/log/splunklogs/*/*/*.log  /opt/splunk/var/log/splunk/splunkd.log



## If you are creating a golden image, run this command before locking to prevent duplicate guids etc
# /opt/splunk/bin/splunk clone-prep-clear-config
