#!/bin/bash
#version: 1.0
#time: 2016.12.6
#author: me
#update@ ?


#路径常量
ceph_dir=/etc/ceph/
ceph_var_dir=/var/lib/ceph/


#事先在本节点上编辑好ceph.conf
echo "开始scp配置文件..."
scp ${ceph_dir}ceph.conf controller1:${ceph_dir}ceph.conf
scp ${ceph_dir}ceph.conf compute1:${ceph_dir}ceph.conf
scp ${ceph_dir}ceph.conf compute2:${ceph_dir}ceph.conf
#scp ${ceph_dir}ceph.conf controller1:${ceph_dir}ceph.conf
#scp ${ceph_dir}ceph.conf controller1:${ceph_dir}ceph.conf
if [ $?="0" ];then
echo "结束scp配置文件!"
else
echo "scp配置文件出错！"
exit
fi


#到各节点创建mon工作目录
echo "开始创建mon"
ssh controller1 "mkdir -p ${ceph_var_dir}mon/ceph-a && ceph-mon -i a --mkfs --fsid `uuidgen`"
#ssh controller2 "mkdir -p ${ceph_var_dir}mon/ceph-b && ceph-mon -i b --mkfs"
#ssh controller3 "mkdir -p ${ceph_var_dir}mon/ceph-c && ceph-mon -i c --mkfs"
if [ $?="0" ];then
echo "结束创建mon!"
else
echo "创建mon出错！"
exit
fi

#启动mon.a{b,c}
echo "开始启动mon"
ssh controller1 "ceph-mon -i a"
#ssh controller2 "ceph-mon -i b"
#ssh controller3 "ceph-mon -i c"
if [ $?="0" ];then
echo "结束启动mon!"
else
echo "启动mon出错！"
exit
fi



#到各节点创建osd工作目录
echo "开始在controller1上创建osd"
ssh controller1 << remotessh
##xfs格式化硬盘
for devs in sdb sdc
do
mkfs.xfs /dev/$devs
done

#创建osd工作目录
for i in 0 1
do
mkdir -p ${ceph_var_lib}osd/ceph-$i
done

#挂载osd盘
mount -o inode64,noatime /dev/sdb ${ceph_var_lib}osd/ceph-0
mount -o inode64,noatime /dev/sdc ${ceph_var_lib}osd/ceph-1

##创建osd守护进程，加入crushmap，启动osd
for i in 0 1
do
id=`ceph osd create`
ceph-osd -i $id --mkfs
ceph osd crush add osd.$id 1 root=default host=controller1
ceph-osd -i $id
done
remotessh 
>>
if [ $?="0" ];then
echo "结束在controller1上创建osd!"
else
echo "在controller1上创建osd出错！"
exit
fi


echo "开始在computepu1上创建osd"
ssh compute1 << remotessh
##xfs格式化硬盘
for devs in sdb sdc
do
mkfs.xfs /dev/$devs
done

#创建osd工作目录
for i in 2 3
do
mkdir -p ${ceph_var_lib}osd/ceph-$i
done

#挂载osd盘
mount -o inode64,noatime /dev/sdb ${ceph_var_lib}osd/ceph-2
mount -o inode64,noatime /dev/sdc ${ceph_var_lib}osd/ceph-3

##创建osd守护进程，加入crushmap，启动osd
for i in 0 1
do
id=`ceph osd create`
ceph-osd -i $id --mkfs
ceph osd crush add osd.$id 1 root=default host=compute1
ceph-osd -i $id
done
remotessh 
>>
if [ $?="0" ];then
echo "结束在compute1上创建osd!"
else
echo "在compute1上创建osd出错！"
exit
fi


echo "开始在compute2上创建osd"
ssh compute2 << remotessh
##xfs格式化硬盘
for devs in sdb sdc
do
mkfs.xfs /dev/$devs
done

#创建osd工作目录
for i in 4 5
do
mkdir -p ${ceph_var_lib}osd/ceph-$i
done

#挂载osd盘
mount -o inode64,noatime /dev/sdb ${ceph_var_lib}osd/ceph-4
mount -o inode64,noatime /dev/sdc ${ceph_var_lib}osd/ceph-5

##创建osd守护进程，加入crushmap，启动osd
for i in 0 1
do
id=`ceph osd create`
ceph-osd -i $id --mkfs
ceph osd crush add osd.$id 1 root=default host=controller1
ceph-osd -i $id
done
remotessh 
>>
if [ $?="0" ];then
echo "结束在compute2上创建osd!"
else
echo "在compute2上创建osd出错！"
exit
fi

