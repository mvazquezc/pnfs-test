#!/usr/bin/bash

set -xe

dnf install -y nfs-utils targetcli

#
# LUN
#
targetcli <<EOF
cd /backstores/fileio/
create /var/tmp/pnfs-lun.img pnfs-lun 4G

cd /loopback/
create naa.1234567890123456
cd naa.1234567890123456/luns
create /backstores/fileio/pnfs-lun
exit
EOF

# Filter for LIO and 4567 which is part of the taregtcli.script def
DEV=$(lsblk --json -p -o NAME,WWN,VENDOR | jq -r '.blockdevices[] | select (.vendor | test(".*LIO.*")) | select(.wwn | test(".*4567.*")) | .name')

mkdir /mnt/pnfs-lun
mkfs.xfs $DEV
mount $DEV /mnt/pnfs-lun
chmod a+rw /mnt/pnfs-lun


#
# NFS Server
#
alias nset="nfsconf --set nfsd"
nset debug 1
nset vers3 n
nset vers4 y
nset vers 4.2 y
nset rdma n

systemctl restart nfs-server

echo "/mnt/pnfs-lun *(rw,insecure)" > /etc/exports
exportfs -rav

#
# NFS Client
#
mkdir /var/tmp/pnfs-mnt
mount -t nfs -o nfsvers=4.2 127.0.0.1:/mnt/pnfs-lun /var/tmp/pnfs-mnt
