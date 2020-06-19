#!/usr/bin/env bash

grub-install /dev/sda                                                           
update-initramfs -u -k all                                                      
update-grub 
