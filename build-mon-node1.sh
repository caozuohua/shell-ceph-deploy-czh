#!/bin/bash
#mon初始化节点
#mon_id一般不用修改
mon_id=a
mkdir -p /var/lib/ceph/mon/ceph-$mon_id
ceph-mon -i ${mon_id} --mkfs
ceph-mon -i ${mon_id}
