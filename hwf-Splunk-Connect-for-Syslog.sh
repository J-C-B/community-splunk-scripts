#!/bin/bash
# 21/07/2021 John Barnett
# Script created on / for CentOS 8

# Added TLS Remix, added TLS listener - note creates a default cert below so edit / remove as required

### Based on quick start here - https://splunk-connect-for-syslog.readthedocs.io/en/master/gettingstarted/quickstart_guide/
### Add cockpit if you like (its great) - sudo systemctl enable --now cockpit.socket - see http://machineip:9090
### podman run -ti drwetter/testssl.sh --severity MEDIUM --ip 127.0.0.1 fooo:6514

# Set URL and Tokens here
HEC_URL="https://127.0.0.1:8088"
HEC_TOKEN="520b411a-3949-4c2c-948a-01eaf6a35f34"
#hostnamectl
#hostnamectl set-chassis server
#hostnamectl set-location rack1
#hostnamectl set-hostname sc4sbuilder
hostnamectl

################################################################################
########### Dont edit below here, unless you know what you are doing ###########
################################################################################
red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`
echo "${yellow}Check date and TZ below!${reset}"
date 
echo "${yellow}Updating Firewall Rules${reset}"
#Show original state
firewall-cmd --list-all
#Splunk ports
firewall-cmd --zone=public --add-port=514/tcp --permanent # syslog TCP
firewall-cmd --zone=public --add-port=514/udp --permanent # syslog UDP
firewall-cmd --zone=public --add-port=6514/tcp --permanent # syslog TLS
firewall-cmd --reload
#Check applied
firewall-cmd --list-all

dnf install -y conntrack podman
echo "
## Edited with JB Splunk Install script by magic
net.core.rmem_default = 17039360
net.core.rmem_max = 17039360
" >> /etc/sysctl.conf

sysctl -p


echo "
## Created with JB Splunk Install script by magic
[Unit]
Description=SC4S Container
Wants=NetworkManager.service network-online.target
After=NetworkManager.service network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Environment=\"SC4S_IMAGE=ghcr.io/splunk/splunk-connect-for-syslog/container:1\"

# Required mount point for syslog-ng persist data (including disk buffer)
Environment=\"SC4S_PERSIST_MOUNT=splunk-sc4s-var:/var/lib/syslog-ng\"

# Optional mount point for local overrides and configurations; see notes in docs
Environment=\"SC4S_LOCAL_MOUNT=/opt/sc4s/local:/etc/syslog-ng/conf.d/local:z\"

# Optional mount point for local disk archive (EWMM output) files
Environment=\"SC4S_ARCHIVE_MOUNT=/opt/sc4s/archive:/var/lib/syslog-ng/archive:z\"

# Uncomment the following line if custom TLS certs are provided
Environment=\"SC4S_TLS_MOUNT=/opt/sc4s/tls:/etc/syslog-ng/tls:z\"

TimeoutStartSec=0

ExecStartPre=/usr/bin/podman pull \$SC4S_IMAGE
ExecStartPre=/usr/bin/bash -c \"/usr/bin/systemctl set-environment SC4SHOST=$(hostname -s)\"

ExecStart=/usr/bin/podman run \\
        -e \"SC4S_CONTAINER_HOST=\${SC4SHOST}\" \\
        -v \$SC4S_PERSIST_MOUNT \\
        -v \$SC4S_LOCAL_MOUNT \\
        -v \$SC4S_ARCHIVE_MOUNT \\
        -v \$SC4S_TLS_MOUNT \\
        --env-file=/opt/sc4s/env_file \\
        --network host \\
        --name SC4S \\
        --rm \$SC4S_IMAGE

Restart=on-abnormal
" > /lib/systemd/system/sc4s.service


sudo podman volume create splunk-sc4s-var
sudo mkdir /opt/sc4s/ 
mkdir /opt/sc4s/local 
mkdir /opt/sc4s/archive 
mkdir /opt/sc4s/tls
# SET CORRECT URL AND HEC TOKEN HERE
echo "
## Created with JB Splunk Install script by magic
# Output config
SPLUNK_HEC_URL=$HEC_URL
SPLUNK_HEC_TOKEN=$HEC_TOKEN
#Uncomment the following line if using untrusted SSL certificates
SC4S_DEST_SPLUNK_HEC_TLS_VERIFY=no
# TLS Config, for McAfee etc
SC4S_SOURCE_TLS_ENABLE=yes
SC4S_LISTEN_DEFAULT_TLS_PORT=6514
#SC4S_SOURCE_TLS_OPTIONS=tls1.2
#SC4S_SOURCE_TLS_CIPHER_SUITE=ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256
" > /opt/sc4s/env_file
echo "${yellow}Generating Cert for TLS${reset}"
openssl req -newkey rsa:2048 -new -nodes -x509 -days 3650 -subj "/C=NZ/ST=NI/L=Home/O=SC4S Name/OU=Org/CN=sc4sbuilder" -keyout /opt/sc4s/tls/server.key -out /opt/sc4s/tls/server.pem
echo "${yellow}Your /opt/sc4s/env_file looks like this${reset}"
cat /opt/sc4s/env_file
echo "${yellow}Starting SC4S - This might take a while first time as the container is downloaded${reset}"
sudo systemctl daemon-reload 
sudo systemctl enable --now sc4s
# Send a test event
echo “Hello MYSC4S” > /dev/udp/127.0.0.1/514
sleep 10
sudo podman logs SC4S
sudo podman ps
# Sleep to allow TLS to come up
sleep 20
netstat -tulpn | grep LISTEN
#### Use command below and then type to test
#openssl s_client -connect localhost:6514
#### Use command below for full tls test if required (adjust as needed)
#podman run -ti drwetter/testssl.sh --severity MEDIUM --ip 127.0.0.1 sc4sbuilder:6514
