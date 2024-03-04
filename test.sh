#!/usr/bin/bash

set -xe

MNT_SERVER=/mnt/pnfs-lun
MNT_CLIENT=/var/tmp/pnfs-client

if ${WITH_CREATE_LUN:-false}
then
  echo dnf install -y nfs-utils targetcli sg3_utils

  #
  # LUN
  #
  targetcli <<EOF
  cd /backstores/fileio/
  create pnfs-lun /var/tmp/pnfs-lun.img 4G

  cd /loopback/
  create naa.1234567890123456
  cd naa.1234567890123456/luns
  create /backstores/fileio/pnfs-lun
  exit
EOF

  # Filter for LIO and 4567 which is part of the taregtcli.script def
  DEV=$(lsblk --scsi --json -p -o NAME,WWN,VENDOR | jq -r '.blockdevices[] | select (.vendor | test(".*LIO-ORG.*")) | .name')

  mkfs.xfs -f $DEV
  mkdir $MNT_SERVER || :
  mount $DEV $MNT_SERVER
  chmod a+rw $MNT_SERVER
fi

#
# NFS Server
#
nset() { nfsconf --set nfsd $@ ; }
nset debug 1
nset vers3 n
nset vers4 y
nset vers 4.1 y
nset vers 4.2 y
nset rdma n

systemctl restart nfs-server

st() { nfsstat -l | grep -E "layout|write" | sort; }
st

#
# NFS Client
#
mkdir $MNT_CLIENT || :
umount $MNT_CLIENT || :

for NFS_FLAGS in "rw,insecure" "pnfs,rw,insecure";
do
  echo -e "\n#\n#\n$NFS_FLAGS\n#\n#\n"

  echo "$MNT_SERVER *($NFS_FLAGS)" > /etc/exports
  exportfs -rav

  mount -t nfs -o nfsvers=4.2 127.0.0.1:/$MNT_SERVER $MNT_CLIENT

  dd if=/dev/zero of=$MNT_CLIENT/data bs=1G count=1
  rm -v $MNT_CLIENT/data
  st

  umount $MNT_CLIENT
done

:> /etc/exports
