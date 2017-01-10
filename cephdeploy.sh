#!/bin/bash
#version: v4.4
#time: 2016.12.6
#author: me
#update@ 2017.1.10
#v1.0：创建——添加所有命令
#version: v4.1
#time: 2016.12.6
#author: me
#update@ 2016.12.22
#v2.0：自动生成配置文件
#v3.0：多mon部署
#v4.0：单脚本部署
#v4.1：配置文件内容重新定义
#v4.2：增加设置chooseleaf = [0,1]（支持单节点部署）；filestore xattr use omap = false（云一般是不使用rgw和mds）
#v4.3: [2017.1.10]修改mon节点数组，实际情况下一般mon节点数和总节点数不一样，所以另外加了个mon_node数组
#v4.4: [2017.1.10]添加判断，如果配置的mon节点数和其ip数量不对应则报错退出；判断osd数量，最少应为2，否则报错退出

##########################################################################
#路径常量，一般不修改
ceph_var_dir='/var/lib/ceph/'

#mon节点信息初始化，根据实际情况修改
mon_init_node='node1'
mon_add_node=('node2' 'node3')
mon_node_ip="192.168.105.197,192.168.105.198,192.168.105.199"
mon_add_length=${#mon_add_node[@]}
mon_node=(${mon_init_node} ${mon_add_node[@]})
mon_num=${#mon_node[@]}
#osd信息初始化,根据实际情况修改
osd_node=('node1' 'node2' 'node3')
dev_list=('/dev/vda')
all_node=${osd_node[@]} 
let osd_num=${#osd_node[@]}*${#dev_list[@]}

let len=${mon_num}-1
if [ -z `echo ${ipp}|cut -d \, -f ${len}` ]
then 
 echo 每个mon节点都应该对应一个IP！请重新配置脚本！
 exit 1
fi

if [ '1' -ge ${#osd_num[@]} ]
then
 echo osd数量至少应为2（对应至少两块硬盘）！！
 exit 1
fi

#请填写ceph.conf中要指定的配置项，根据实际情况修改
#一般默认3副本
#pg数量确认公式：pg=(osd_num×100)/3
#主要修改network
auth_cluster_required='none'
auth_server_required='none'
auth_client_required='none'
log_file='/var/log/ceph.log'
osd_pool_default_pg_num='128'
osd_pool_default_pgp_num='128'
osd_crush_update_on_start='false'
osd_pool_default_size='2'
osd_pool_default_min_size='1'
public_network='192.168.105.0/24'
cluster_network='192.168.105.0/24'
##########################################################################



###############################开始执行命令####################################
echo "++++++++++++++++++++++++++++`date`++++++++++++++++++++++++++++++++++++++"
ceph_uuid=`uuidgen`
#事先在本节点上编辑好ceph.conf
echo '初始化ceph.conf...'
cephconf='/etc/ceph/ceph.conf'
touch /etc/ceph/ceph.conf
if [ ! -e ${cephconf} ];then
 echo 请确保/etc/ceph/ceph.conf文件存在！
 exit 1
fi
if [ ${#all_node[@]} -eq '0' ]
then 
 echo 请重新修改脚本文件配置项！
 exit 1
elif [ ${#all_node[@]} -eq '1' ]
 then
  osd_crush_chooseleaf_type='0'
else
 osd_crush_chooseleaf_type='1'
fi
#------------------------以下为配置文件必需的配置项---------------------------
echo "[global]" > ${cephconf}
echo "fsid = ${ceph_uuid}" >> ${cephconf}
echo "mon initial members = ${mon_node[*]}" >> ${cephconf}
echo "mon host = ${mon_node_ip}" >> ${cephconf}
echo "public network = ${public_network}" >> ${cephconf}
echo "cluster network = ${cluster_network}" >> ${cephconf}
echo "auth cluster required = ${auth_cluster_required}" >> ${cephconf}
echo "auth service required = ${auth_server_required}" >> ${cephconf}
echo "auth client required = ${auth_client_required}" >> ${cephconf}
echo "log file = ${log_file}" >> ${cephconf}
echo "osd pool default size = ${osd_pool_default_size}" >> ${cephconf}
echo "osd pool default min size = ${osd_pool_default_min_size}" >> ${cephconf}
echo "filestore xattr use omap = false" >> ${cephconf}
echo "osd crush chooseleaf type = ${osd_crush_chooseleaf_type}" >> ${cephconf}
echo "osd pool default pg num = ${osd_pool_default_pg_num}" >> ${cephconf}
echo "osd pool default pgp num = ${osd_pool_default_pgp_num}" >> ${cephconf}
echo "osd crush update on start  = ${osd_crush_update_on_start}" >> ${cephconf}
#---------------------------------------------------------

echo '++++++++++++++++++++++++++ceph集群部署开始+++++++++++++++++++++++++++++++'
echo '开始scp配置文件...'
for i in ${all_node[@]}
 do
 echo ${i}节点scp配置文件...
 scp ${cephconf} ${i}:${cephconf}
done

sleep 3

#到各节点创建mon工作目录
echo '+++++++++++++++++++++++++++开始创建mon++++++++++++++++++++++++++++++++++'
echo 初始mon节点${mon_init_node}启动...
mkdir -p ${ceph_var_dir}mon/ceph-${mon_init_node} 
ceph-mon -i ${mon_init_node} --mkfs
ceph-mon -i ${mon_init_node}
if [ ${mon_add_length} -gt '0' ]
then
 sleep 5
 for (( j=0;j<${mon_add_length};j++ ))
  do
   sleep 5
   echo mon节点${mon_add_node[${j}]}启动...
   echo 创建mon.${mon_add_node[${j}]}]}目录
   ssh ${mon_add_node[${j}]} "mkdir -p ${ceph_var_dir}mon/ceph-${mon_add_node[${j}]} "
   echo 创建mon.${mon_add_node[${j}]}
   ssh ${mon_add_node[${j}]} "ceph-mon -i ${mon_add_node[${j}]} --mkfs"
   sleep 10
   echo 启动mon.${mon_add_node[${j}]}
   ssh ${mon_add_node[${j}]} "ceph-mon -i ${mon_add_node[${j}]}"
 done
fi

#到各节点创建osd工作目录
echo '+++++++++++++++++++++++++++++开始创建osd+++++++++++++++++++++++++++++'
for k in ${osd_node[@]}
 do
 echo 节点${k}开始启动osd
 for dev in ${dev_list[@]}
  do
  sleep 5
  id=`ssh ${k} "ceph osd create"`
  echo 创建osd:${id}...
  ssh ${k} "mkdir -p ${ceph_var_dir}osd/ceph-${id}"
  ssh ${k} "umount -f ${dev} > /dev/null 2>&1"
  ssh ${k} "mkfs.xfs ${dev} -f"
  ssh ${k} "mount -o inode64,noatime ${dev} /var/lib/ceph/osd/ceph-${id}"
  ssh ${k} "ceph-osd -i ${id} --mkfs"
  sleep 5
  ssh ${k} "ceph osd crush add osd.${id} 1 root=default host=${k}"
  ssh ${k} "ceph-osd -i ${id}"
 done
 if [ $? -eq '0' ]
 then
 echo ${k}节点创建osd.${id}成功！
 else
 echo ${k}节点创建osd失败！请检查本脚本和ceph.conf！
 exit 1
 fi
done

##################################################################################
echo "---------------------`date`:cephdeploy.sh运行结束--------------------------"
