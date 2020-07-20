#!/bin/bash

# 20/07/2020 John Barnett
# Script created on / for CentOS 8

### Based on quick start here - https://splunk-connect-for-syslog.readthedocs.io/en/master/gettingstarted/quickstart_guide/

### Add cockpit if you like (its great) - sudo systemctl enable --now cockpit.socket - see http://machineip:9090

# Set URL and Tokens here
HEC_URL="https://mysplunk:8088"
HEC_TOKEN="67607ad6-2f6d-432c-8f2d-b1ef094e2f3f"

#hostnamectl
#hostnamectl set-chassis server
#hostnamectl set-location rack1
#hostnamectl set-hostname sc4syslog
#hostnamectl

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
reset=`tput sgr0`

echo "${yellow}Check date and TZ below!${reset}"

date 

dnf install -y conntrack podman

echo "
## Edited with JB Splunk Install script by magic

net.core.rmem_default = 1703936
net.core.rmem_max = 1703936
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
Environment=\"SC4S_IMAGE=splunk/scs:latest\"

# Required mount point for syslog-ng persist data (including disk buffer)
Environment=\"SC4S_PERSIST_VOLUME=-v splunk-sc4s-var:/opt/syslog-ng/var\"

# Optional mount point for local overrides and configurations; see notes in docs
Environment=\"SC4S_LOCAL_CONFIG_MOUNT=-v /opt/sc4s/local:/opt/syslog-ng/etc/conf.d/local:z\"

# Optional mount point for local disk archive (EWMM output) files
# Environment=\"SC4S_LOCAL_ARCHIVE_MOUNT=-v /opt/sc4s/archive:/opt/syslog-ng/var/archive:z\"

# Uncomment the following line if custom TLS certs are provided
# Environment=\"SC4S_TLS_DIR=-v /opt/sc4s/tls:/opt/syslog-ng/tls:z\"

TimeoutStartSec=0
Restart=always

ExecStartPre=/usr/bin/podman pull \$SC4S_IMAGE
ExecStartPre=/usr/bin/bash -c \"/usr/bin/systemctl set-environment SC4SHOST=$(hostname -s)\"
ExecStart=/usr/bin/podman run -p 514:514 -p 514:514/udp -p 6514:6514 \
        -e \"SC4S_CONTAINER_HOST=${SC4SHOST}\" \
        --env-file=/opt/sc4s/env_file \
        "$SC4S_PERSIST_VOLUME" \
        "$SC4S_LOCAL_CONFIG_MOUNT" \
        "$SC4S_LOCAL_ARCHIVE_MOUNT" \
        "$SC4S_TLS_DIR" \
        --name SC4S \
        --rm \$SC4S_IMAGE
ExecStartPost=sleep 2 ; conntrack -D -p udp
Restart=on-success


" > /lib/systemd/system/sc4s.service


sudo podman volume create splunk-sc4s-var

sudo mkdir /opt/sc4s/ 
mkdir /opt/sc4s/local 
mkdir /opt/sc4s/archive 
mkdir /opt/sc4s/tls

# SET CORRECT URL AND HEC TOKEN HERE
echo "## Created with JB Splunk Install script by magic
SPLUNK_HEC_URL=$HEC_URL
SPLUNK_HEC_TOKEN=$HEC_TOKEN
#Uncomment the following line if using untrusted SSL certificates
SC4S_DEST_SPLUNK_HEC_TLS_VERIFY=no
" > /opt/sc4s/env_file

echo "${yellow}Your /opt/sc4s/env_file looks like this${reset}"
cat /opt/sc4s/env_file

echo "${yellow}Starting SC4S - This might take a while first time as the container is downloaded${reset}"

#echo "Starting SC4S - This might take a while first time as the container is downloaded"
sudo systemctl daemon-reload 
sudo systemctl enable --now sc4s

# Send a test event
echo “Hello SC4S” > /dev/udp/127.0.0.1/514

sudo podman logs SC4S
