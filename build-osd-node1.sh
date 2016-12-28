#!/bin/bash
#hostname for ceph in ceph-osd-crush-map

#请根据实际情况修改hostname和dev_list
hostname=node1
dev_list=(vda vdc)

for i in ${dev_list[@]}
do
id=`ceph osd create`
mkdir -p /var/lib/ceph/osd/ceph-${id}
umount /dev/${i} > /dev/null 2>&1
mkfs.xfs -f /dev/${i}
mount -o inode64,noatime /dev/${i} /var/lib/ceph/osd/ceph-${id}
ceph-osd -i ${id} --mkfs
ceph osd crush add osd.${id} 1 root=default host=${hostname}
ceph-osd -i ${id}
done
