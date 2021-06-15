# Build scripts to create basic splunk nodes or heavy forwarders with syslog-ng

## Purpose

This repo is for community scripts to be shared from.

****These scripts are community focused and not supported or endorsed by Splunk, use at your own risk****

Scripts starting "enterprise" are designed to create a vanilla splunk enterprise node, which can be configured into an indexer, search head or any other node as required after script run

Scripts starting "hwf" are designed to create a base HWF with Syslog-NG configured and ready to receive events, with Splunk set to monitor those folders - check the video link below for an 8 minute run through

## Video of installation guide and deep dive for *centos syslog-ng HWF* scripts

https://www.youtube.com/channel/UCnJs921W67iy2LdBzr8kC2A

## Video installation guide for centos *Splunk connect for syslog (SC4S)*

https://www.youtube.com/channel/UCnJs921W67iy2LdBzr8kC2A


## Notes

* The splunk admin password is hardcoded into the script, ensure it is changed before / after the installation
* Any HWF addons are installed from a static `.tar` so may be out of date, update if required after script run
* For splunk cloud customers, contact Splunk support for a free heavy forwarder licence
* These scripts are designed to be run on a vanilla fresh install of centos, they take no care for any existing configuration
* If you are creating a golden image, run this command before locking to prevent duplicate guids etc `/opt/splunk/bin/splunk clone-prep-clear-config`

## Project home page

https://gitlab.com/J-C-B/community-splunk-scripts


...