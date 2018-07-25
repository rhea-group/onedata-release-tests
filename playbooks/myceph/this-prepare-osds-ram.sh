#!/bin/bash
########################################
# Prepare ram osd on this host. It assumes  
if [ " "$1 = " " ]; then 
  echo No args. Usage: "$0 <num-disks> <vol-prefix> <size>"  # 1 ram
  exit 1;
fi
#NUM_DISKS=$1
#VOL_PREFIX=$2
SIZE=$3
#for c in 0n1; do
 #   DISK=${VOL_PREFIX}${c}
    OSD_ID=`sudo ceph osd create`
    echo OSD_ID=${OSD_ID}
    sudo mkdir /var/lib/ceph/osd/ceph-${OSD_ID}
    echo Created dir
    sudo rmmod brd
    S=`echo "$3 * 2 ^ 20"|bc`
    sudo modprobe brd rd_size=$S max_part=2 rd_nr=1
    sudo mkfs -t xfs /dev/ram0
    echo After mkfs
    sudo mount /dev/ram0 /var/lib/ceph/osd/ceph-${OSD_ID}
    echo Adding to fstab
    #sudo bash -c "echo $DISK /var/lib/ceph/osd/ceph-${OSD_ID} xfs defaults 0 0 >> /etc/fstab"
    echo after mount
    sudo ceph-osd -i ${OSD_ID} --mkfs --mkkey
    echo after initializing osd dir
    echo Executing: sudo ceph auth add osd.${OSD_ID} osd 'allow *' mon 'allow rwx' -i /var/lib/ceph/osd/ceph-${OSD_ID}/keyring
    sudo ceph auth add osd.${OSD_ID} osd 'allow *' mon 'allow rwx' -i /var/lib/ceph/osd/ceph-${OSD_ID}/keyring
    echo after auth
    sudo chown -R ceph:ceph  /var/lib/ceph/osd/ceph-${OSD_ID}
    echo after chown
    sudo systemctl start ceph-osd@${OSD_ID}
    sudo systemctl enable ceph-osd@${OSD_ID}
    echo after systemctl
    
#    let i=i+1
#    if [ $i -gt $NUM_DISKS ]; then
#	break
#    fi
#    echo $DISK
#done

#if [ $i -le $NUM_DISKS ]; then
#    echo TODO
#fi

exit
    
    
# for ((i='b'; i<'b'+$NUM_DISKS; i++)) do
#     DISK="/dev/xvd"$b
#     echo $DISK
# done
# exit
    
