#!/bin/bash
#version：v4.2
#update:2016-1223
#利用ceph包自带的工具monmaptool创建mon，ceph-disk创建osd

ceph_conf='/etc/ceph/ceph.conf'
ceph_fsid=`uuidgen`

#执行本脚本前根据实际情况修改一下参数##############################
mon_node=('node1' 'node2' 'node3')
mon_node_ip="192.168.105.197,192.168.105.198,192.168.105.199"
#mon_num=${#mon_node[@]}
osd_node=('node1' 'node2' 'node3')
dev_list=('vda')
all_node=${osd_node[@]}
###################################################################
auth_cluster_required='none'
auth_server_required='none'
auth_client_required='none'
log_file='/var/log/ceph.log'
osd_pool_default_pg_num='128'
osd_pool_default_pgp_num='128'
#osd_crush_update_on_start='false'
osd_pool_default_size='2'
osd_pool_default_min_size='1'
public_network='192.168.105.0/24'
cluster_network='192.168.105.0/24'
##################################################################

###########################开始执行命令###########################
if [ ! -e ${ceph_conf} ];then
 echo /etc/ceph/ceph.conf文件不存在！将自动创建！
 touch /etc/ceph/ceph.conf
 if [ $? -nq '0' ];then
 echo 'touch /etc/ceph/ceph.conf 文件失败！'
 exit 1
 fi
fi

#生成配置文件
echo '开始写入/etc/ceph/ceph.conf...'
echo "[global]" > ${cephp_conf}
echo "fsid = ${ceph_fsid}" >> ${ceph_conf}
echo "mon initial menbers = ${mon_node[*]}" >> ${ceph_conf}
echo "mon host = ${mon_node_ip}" >> ${ceph_conf}
echo "public_network = ${public_network}" >> ${ceph_conf}
echo "cluster_network = ${cluster_network}" >> ${ceph_conf}
echo "auth cluster required = ${auth_cluster_required}" >> ${cephconf}
echo "auth service required = ${auth_server_required}" >> ${cephconf}
echo "auth client required = ${auth_client_required}" >> ${cephconf}
echo "log file = ${log_file}" >> ${cephconf}
echo "osd pool default size = ${osd_pool_default_size}" >> ${cephconf}
echo "osd pool default min size = ${osd_pool_default_min_size}" >> ${cephconf}

#添加mon
echo "在`hostname -s`上开始创建mon..."
mon_map=/tmp/monmap
for (( i=0;i<${#mon_node[@]};i++ ))
do
 let j=${i}+1
  if [ ${i} -eq '0' ];then
  monmaptool --create --add ${mon_node[${i}]} `echo ${mon_node_ip}| cut -d , -f ${j}`  --fsid ${ceph_fsid} ${mon_map}
  else
  monmaptool --add ${mon_node[${i}]} `echo ${mon_node_ip}| cut -d , -f ${j}`  --fsid ${ceph_fsid} ${mon_map}
  fi
done

#准备配置文件
echo '开始scp配置文件...'
for i in ${all_node[@]}
 do
 echo "节点${i}scp配置文件..."
 scp ${ceph_conf} ${i}:${ceph_conf}
done

#添加mon
for k in ${mon_node[@]}
do
 echo "节点${k}开始分配monmap..."
 scp ${mon_map} ${k}:${mon_map}
 echo "节点${k}开始启动mon..."
 ssh ${k} "mkdir -p /var/lib/ceph/mon/ceph-${k}"
 ssh ${k} "ceph-mon --cluster ceph --mkfs -i ${k} --monmap ${mon_map}"
 ssh ${k} "touch /var/lib/ceph/mon/ceph-${k}/done"
 ssh ${k} "ceph-mon -i ${k}"
done

#添加osd
for i in ${osd_node[@]}
do
 for dev in ${dev_list[@]}
 do
  echo "节点${i}开始为磁盘${dev}启动osd..."
  ssh ${i} "ceph-disk prepare --cluster ceph --cluster-uuid ${ceph_fsid} --fs-type xfs ${dev}"
  ssh ${i} "partprobe"
  ssh ${i} "ceph-disk activate ${dev}1"
 done
done

echo "================================脚本运行完毕======================================="
