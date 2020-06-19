#!/usr/bin/env bash

apt update && apt-get -y upgrade
apt -y install busybox dropbear dropbear-initramfs
rm -rf /var/cache/apt/archives/\*
