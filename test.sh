#!/usr/bin/bash

set -x
#set -e
set -m

MNT_SERVER=/mnt/pnfs-lun
MNT_SERVER_REFER=/mnt/pnfs-lun-refer
MNT_CLIENT=/var/tmp/pnfs-client

if ${WITH_CREATE_LUN:-false}
then
  echo dnf install -y nfs-utils targetcli sg3_utils

  #
  # LUN
  #
  targetcli <<EOF
  cd /backstores/fileio/
  create pnfs-lun /var/tmp/pnfs-lun.img 5G

  cd /loopback/
  create naa.1234567890123456
  cd naa.1234567890123456/luns
  create /backstores/fileio/pnfs-lun
  exit
EOF

  # Filter for LIO and 4567 which is part of the taregtcli.script def
  DEV=$(lsblk --scsi --json -p -o NAME,WWN,VENDOR | jq -r '.blockdevices[] | select (.vendor | test(".*LIO-ORG.*")) | .name')

  mkfs.xfs -f $DEV
  mkdir -p $MNT_SERVER || :
  mount $DEV $MNT_SERVER
  chmod a+rw $MNT_SERVER

  mkdir -p $MNT_SERVER_REFER || :
  mount -o bind $MNT_SERVER_REFER $MNT_SERVER_REFER
fi

if ${WITH_CONFIGURE_NFS:-true}
then
  #
  # NFS Server
  #
  nfsconf --set exportd debug all
  nfsconf --set mountd debug all

  nset() { nfsconf --set nfsd $@ ; }
  nset debug 1
  nset vers3 n
  nset vers4 y
  nset vers 4.1 y
  nset vers 4.2 y
  nset rdma n

  systemctl restart nfs-server
fi

st() { nfsstat -l | grep -E "layout|write" | sort; }
st

#
# NFS Client
#

declare -A results

mkdir -p $MNT_CLIENT || :
umount $MNT_CLIENT || :

for NFS_FLAGS in "rw,insecure" "pnfs,rw,insecure,replicas=$MNT_SERVER@10.0.2.2:$MNT_SERVER@127.0.0.1";
do
  echo -e "\n#\n#\n$NFS_FLAGS\n#\n#\n"

  tee /etc/exports.d/pnfs.exports <<EOF
$MNT_SERVER_REFER *(refer=${MNT_SERVER}@127.0.0.1)
$MNT_SERVER *($NFS_FLAGS)
EOF
  K=$( [[ "$NFS_FLAGS" =~ .*pnfs.* ]] && echo pnfs || echo no-pnfs )
  exportfs -rav

  mount -t nfs -o nfsvers=4.2,actimeo=600 127.0.0.1:/$MNT_SERVER_REFER $MNT_CLIENT

  results[$K]=$(dd if=/dev/zero of=$MNT_CLIENT/data bs=1G count=3 2>&1 ; sync)

  if ${INTERRUPT_NFS:-false} && [[ "$NFS_FLAGS" =~ .*pnfs.* ]]
  then
    # FIXME better with iptables rules
    { sleep 1 ; ip link set eth0 down ; sleep 5 ; ip link set eth0 up ; } &
    results[${K}X]=$(dd if=/dev/zero of=$MNT_CLIENT/data bs=1G count=3 2>&1 ; sync)
    #systemctl stop nfs-server
    #systemctl start nfs-server
    
    fg +1 || :
  fi

  rm -v $MNT_CLIENT/data
  st

  umount $MNT_CLIENT
  rm /etc/exports.d/pnfs.exports
  exportfs -rav
done

for i in "${!results[@]}"
do
echo -e "# ${i}\n${results[$i]}"
done

