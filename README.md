# shell-ceph-deploy-czh
============
>请不吝赐教！

##本脚本目的是为了配置openstack云可用的ceph集群，可以为glance、cinder和nova提供存储资源——不应该应用于专业的存储需求

####【注意！】  

1.使用bash脚本代替手动部署，在第一个mon节点上执行脚本即可  
2.必须事先规划好存储网络，配置好ip、hostname和hosts文件，然后配置各节点ssh免密码  
3.根据实际情况，在注释提示下设置脚本开头的变量（例如主机名、磁盘列表和IP等），相应主机和ip要一一对应  
4.osd节点上的硬盘数量必须一致  
5.ublic network和cluster network可以设置成同一个网段  
6.配置项酌情设置
