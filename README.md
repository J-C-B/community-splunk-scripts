# Build scripts to create a basic splunk node or heavy forwarder

## Purpose

This repo is for community scripts to be shared from.

****These scripts are community focused and not supported or endorsed by Splunk, use at your own risk****

## Video and installation guide for centos HWF scripts

https://www.youtube.com/channel/UCnJs921W67iy2LdBzr8kC2A

## Notes

* The splunk admin password is hardcoded into the script, ensure it is changed before / after the installation
* The addons are installed from a static `.tar` so may be out of date, update if required after script run
* For splunk cloud customers, contact support for a free heavy forwarder licence
* These scripts are designed to be run on a vanilla fresh install, they take no care for any existing configuration
* If you are creating a golden image, run this command before locking to prevent duplicate guids etc `/opt/splunk/bin/splunk clone-prep-clear-config`
