#!/usr/bin/bash

set -x
#set -e
set -m

LUN_SERVER=/dev/pnfs-lun
MNT_SERVER=/mnt/pnfs-lun
MNT_SERVER_REFER=/mnt/pnfs-lun-refer

create_fake_lun() { # --> DEV
  #
  # LUN
  #
  {
    targetcli <<EOF
    cd /backstores/fileio/
    create pnfs-lun /var/tmp/pnfs-lun.img 5G

    cd /loopback/
    create naa.1234567890123456
    cd naa.1234567890123456/luns
    create /backstores/fileio/pnfs-lun
    exit
EOF
  } >&2

  # Filter for LIO and 4567 which is part of the taregtcli.script def
  DEV=$(lsblk --scsi --json -p -o NAME,WWN,VENDOR | jq -r '.blockdevices[] | select (.vendor | test(".*LIO-ORG.*")) | .name')

  echo "DEV=$DEV"
}

UNUSUED_AS_EXPECTED_create_xfs() {
  mkfs.xfs -f $DEV
  mkdir -p $MNT_SERVER || :
}

# IDEA
# Run separate referer
# Run separate MDS
run_referer() {
  MY_IP="10.0.1.1"
  REPLICA_IPS="10.0.2.2"
  NFS_FLAGS="pnfs,rw,insecure,replicas="
  for REPLICA_IP in $REPLICA_IPS;
  do
    NFS_FLAGS+="$MNT_SERVER@$REPLICA_IP:"
  done

  # REFERER still requires a mounted path
  mkdir -p $MNT_SERVER_REFER || :
  mount -o bind $MNT_SERVER_REFER $MNT_SERVER_REFER

  tee /etc/exports.d/pnfs-referer.exports <<EOF
$MNT_SERVER_REFER *(refer=${MNT_SERVER}@${MY_IP})
EOF
  exportfs -rav

  # in poc we did then also run_mds()
}

#fsid=0 required (https://www.linuxquestions.org/questions/linux-networking-3/nfs-mount-no-such-file-or-directory-4175531974/)

run_mds() {
  NFS_FLAGS="pnfs,rw,insecure,fsid=0"

#  mkfs.xfs $LUN_SERVER
#  mkdir -p $MNT_SERVER
#  mount $LUN_SERVER $MNT_SERVER
  mkdir -p $MNT_SERVER
  mount $LUN_SERVER $MNT_SERVER
  chmod a+rw $MNT_SERVER
  # share must be owned by libvirt uid:gid (107), otherwise: preparing host-disks failed: chown /proc/3402156/root/var/run/kubevirt-private/vmi-disks/rootdisk/disk.img: operation not permitted
  chown -R 107:107 $MNT_SERVER
  tee /etc/exports.d/pnfs-mds.exports <<EOF
$MNT_SERVER *($NFS_FLAGS)
EOF
  exportfs -rav

  /usr/sbin/rpcbind &
  /usr/sbin/rpc.mountd &
  /usr/sbin/rpc.idmapd &
  /usr/sbin/rpc.statd &
  /usr/sbin/rpc.nfsd &
  /usr/sbin/blkmapd &

}

main() {
  case $MODE in

    referer)
      run_referer
      ;;

    mds)
      run_mds
      ;;

    *)
      echo "Unknown mode: $MODE"
      exit 1
      ;;
  esac
}

main

dmesg -w
