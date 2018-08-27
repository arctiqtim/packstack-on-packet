#!/bin/bash

parted /dev/nvme0n1 mklabel gpt
parted /dev/nvme0n1 unit gib mkpart primary 1 500 set 1 lvm on
parted /dev/nvme0n1 unit gib mkpart primary 500 1500 set 2 lvm on

yum -y install lvm2

pvcreate /dev/nvme0n1p1
pvcreate /dev/nvme0n1p2

vgcreate varlib /dev/nvme0n1p1
lvcreate -l 100%FREE varlib -n varlib
mkfs.ext4 /dev/mapper/varlib-varlib

systemctl stop openstack-*
systemctl stop neutron-*
systemctl stop mariadb
systemctl stop httpd
systemctl stop libvirtd

systemctl disable openstack-losetup

# Remove old cinder-volumes
vgrename cinder-volumes cinder-volumes-old

vgcreate cinder-volumes /dev/nvme0n1p2

mkdir /mnt/varlibtmp
mount /dev/mapper/varlib-varlib /mnt/varlibtmp

cp -ax /var/lib/* /mnt/varlibtmp
mv /var/lib /var/lib.backup
echo -e "UUID=$(lsblk /dev/mapper/varlib-varlib -no UUID)\t/var/lib\text4\tdefaults\t0\t0" >> /etc/fstab
mkdir /var/lib
umount /mnt/varlibtmp
mount -a
