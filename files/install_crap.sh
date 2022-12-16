#!/usr/bin/env bash

echo "nameserver 127.0.0.53" >> /etc/resolv.conf

apt update && apt-get -y upgrade
apt -y install busybox dropbear dropbear-initramfs
rm -rf /var/cache/apt/archives/\*

rm /etc/resolv.conf
