#!/bin/bash

# 说明：首先通过Cobbler Profile “RHEL7.3-x86_64-kvm”，完成系统自动部署，然后执行本脚本完成宿主机bjape01-kvm1的安装及配置。因为中间涉及IP地址修改和输入密码的操作，所以本脚本只能在控制台执行。
# 注：本脚本适用于以下配置的服务器：
#     1、服务器型号为HP DL388系列，其他品牌、型号未经验证。主要的差别在于支持PXE的网卡以及网卡名称。最新的HP服务器只支持网卡eno0进行PXE引导；
#     2、服务器配置两组raid阵列，第二组为高速磁盘。当然不是高速磁盘的情况也可以用此脚本；
#     3、服务器配置四块网卡，网卡eno1、eno3绑定为bond0，网卡eno4作为宿主机管理口；

# 脚本调试开关，调试时启用。调试后运行该脚本时屏蔽下面行，或改为set +x。如需输出脚本运行日志，可保留不变。
set -x -v

# 指定日志文件和FIFO文件，用于通过FIFO文件将日志执行结果同时输出到标准输出和日志文件
logFile=/root/system-custom.log
fifoFile=/root/.system-custom.fifo
if [ -a ${fifoFile} ]
then
  echo "FIFO文件/root/.system-custom.fifo已存在"
else
  mkfifo ${fifoFile}
fi
cat ${fifoFile} | tee ${logFile} &
exec 1>${fifoFile} 2>&1

### 第一部分：系统基本设置

# 下载环境对应Banner文件
rm -f /etc/motd
wget -q -O /etc/motd http://cobbler/configfile/motd/${env}-motd
echo "------------------检查结果------------------"
cat /etc/motd

# 设置hosts文件
sed -i 's/ads1/bjape01-ads1/g' /etc/hosts
sed -i 's/ms20/bjape01-ms20/g' /etc/hosts
echo '# localhost
172.16.216.1     bjape01-kvm1
' | tee -a /etc/hosts
echo "------------------检查结果------------------"
cat /etc/hosts

# 设置主机名
echo 'bjape01-kvm1' > /etc/hostname
hostname bjape01-kvm1
echo "------------------检查结果------------------"
cat /etc/hostname

# 配置硬盘sdb
fdisk /dev/sdb << EOF
n
p
1
2048

t
8e
w
EOF

pvcreate /dev/sdb1
vgcreate vg1 /dev/sdb1
lvcreate -n image -l 100%FREE vg1
mkfs.xfs /dev/vg1/image
mkdir /var/lib/libvirt/images-fast
mount /dev/mapper/vg1-image /var/lib/libvirt/images-fast
echo '/dev/mapper/vg1-image   /var/lib/libvirt/images-fast   xfs    defaults        0 0' >> /etc/fstab
echo "------------------检查结果------------------"
fdisk -l /dev/sdb
pvs
vgs
lvs
ls -la /var/lib/libvirt
df -hT

# 配置虚机通信接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=eno1
DEVICE=eno1
ONBOOT=yes
MASTER=bond0
SLAVE=yes
' > /etc/sysconfig/network-scripts/ifcfg-eno1

echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=eno3
DEVICE=eno3
ONBOOT=yes
MASTER=bond0
SLAVE=yes
' > /etc/sysconfig/network-scripts/ifcfg-eno3

echo 'TYPE=Bond
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0
DEVICE=bond0
ONBOOT=yes
BONDING_MASTER=yes
BONDING_OPTS="mode=1 miimon=100"
BRIDGE=br0
' > /etc/sysconfig/network-scripts/ifcfg-bond0

echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br0
DEVICE=br0
ONBOOT=yes
STP=yes
BRIDGING_OPTS=priority=32768
' > /etc/sysconfig/network-scripts/ifcfg-br0

# 配置APP区 vlan 3接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.3
DEVICE=bond0.3
ONBOOT=yes
BRIDGE=br3
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.3
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br3
DEVICE=br3
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br3

# 配置APP区 vlan 51接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.51
DEVICE=bond0.51
ONBOOT=yes
BRIDGE=br51
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.51
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br51
DEVICE=br51
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br51

# 配置APP区 vlan 53接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.53
DEVICE=bond0.53
ONBOOT=yes
BRIDGE=br53
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.53
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br53
DEVICE=br53
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br53

# 配置APP区 vlan 54接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.54
DEVICE=bond0.54
ONBOOT=yes
BRIDGE=br54
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.54
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br54
DEVICE=br54
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br54

# 配置APP区 vlan 56接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.56
DEVICE=bond0.56
ONBOOT=yes
BRIDGE=br56
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.56
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br56
DEVICE=br56
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br56

# 配置APP区 vlan 57接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.57
DEVICE=bond0.57
ONBOOT=yes
BRIDGE=br57
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.57
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br57
DEVICE=br57
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br57

# 配置APP区 vlan 58接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.58
DEVICE=bond0.58
ONBOOT=yes
BRIDGE=br58
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.58
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br58
DEVICE=br58
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br58

# 配置APP区 vlan 59接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.59
DEVICE=bond0.59
ONBOOT=yes
BRIDGE=br59
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.59
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br59
DEVICE=br59
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br59

# 配置DB区vlan 5接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=bond0.5
DEVICE=bond0.5
ONBOOT=yes
BRIDGE=br5
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-bond0.5
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br5
DEVICE=br5
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br5

# 配置主机管理接口
echo 'TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
NAME=eno4
DEVICE=eno4
ONBOOT=yes
IPADDR=172.16.216.1
NETMASK=255.255.255.0
GATEWAY=172.16.216.254
' > /etc/sysconfig/network-scripts/ifcfg-eno4

# 配置管理区vlan 244接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=eno4.244
DEVICE=eno4.244
ONBOOT=yes
BRIDGE=br244
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-eno4.244
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br244
DEVICE=br244
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br244

# 配置管理区vlan 245接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=eno4.245
DEVICE=eno4.245
ONBOOT=yes
BRIDGE=br245
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-eno4.245
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br245
DEVICE=br245
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br245

# 配置管理区vlan 246接口
echo 'TYPE=Ethernet
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=eno4.246
DEVICE=eno4.246
ONBOOT=yes
BRIDGE=br246
STP=yes
VLAN=yes
' > /etc/sysconfig/network-scripts/ifcfg-eno4.246
echo 'TYPE=Bridge
BOOTPROTO=none
IPV4_FAILURE_FATAL=yes
NAME=br246
DEVICE=br246
ONBOOT=yes
STP=yes
' > /etc/sysconfig/network-scripts/ifcfg-br246

echo "------------------检查结果------------------"
ls -la /etc/sysconfig/network-scripts/

### 第二部分：设置用户环境

# 设置SSH免密登录
mkdir /root/.ssh
wget -q -O /root/ops11-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops11-root-id_rsa.pub
wget -q -O /root/ops12-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops12-root-id_rsa.pub
wget -q -O /root/kvm01-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-kvm01-root-id_rsa.pub
touch /root/.ssh/authorized_keys
cat /root/ops11-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/ops12-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/kvm01-id_rsa.pub >> /root/.ssh/authorized_keys
rm -f /root/*id_rsa.pub
chown -R root:root /root/.ssh
chmod -R 600 /root/.ssh
echo "------------------检查结果------------------"
ls -la /root/.ssh
cat /root/.ssh/authorized_keys

### 第三部分：通用软件安装及配置，略过

### 第四部分：系统安全加固

# 调整root账号ssh登录源IP限制
sed -i 's/172.16.244.11 172.16.244.12/172.16.244.11 172.16.244.12 172.16.216.1 172.16.1.145/g' /etc/security/access.conf
echo "------------------检查结果------------------"
tail /etc/security/access.conf

### 第五部分：节点定制系统优化

# 启用numad服务，支持NUMA的双CPU物理服务器建议启用
systemctl enable numad
systemctl start numad
echo "------------------检查结果------------------"
systemctl status numad

### 第六部分：节点定制软件安装及配置

# 设置vnc密码，开启vnc服务。注意：必须先设置vnc密码，vncserver服务才能正常启动。此处需要手工输入两次密码，如果不是SSH登录后执行本脚本，输入命令时无回显提示，需要谨慎输入两次密码。
vncpasswd
systemctl start vncserver@:1
echo "------------------检查结果------------------"
systemctl status vncserver@:1

# 根据运维人员数量配置多组vncserver，避免争用
cp /lib/systemd/system/vncserver\@:1.service /lib/systemd/system/vncserver\@:2.service
cp /lib/systemd/system/vncserver\@:1.service /lib/systemd/system/vncserver\@:3.service
cp /lib/systemd/system/vncserver\@:1.service /lib/systemd/system/vncserver\@:4.service
cp /lib/systemd/system/vncserver\@:1.service /lib/systemd/system/vncserver\@:5.service
systemctl enable vncserver@:2
systemctl start vncserver@:2
systemctl enable vncserver@:3
systemctl start vncserver@:3
systemctl enable vncserver@:4
systemctl start vncserver@:4
systemctl enable vncserver@:5
systemctl start vncserver@:5
echo "----------------result check----------------"
systemctl status vncserver@:2
systemctl status vncserver@:3
systemctl status vncserver@:4
systemctl status vncserver@:5
ss -lantp | grep vnc

# 增加虚拟机存储池
chmod 711 /var/lib/libvirt/images-fast
virsh pool-define-as images-fast --type dir --target /var/lib/libvirt/images-fast
virsh pool-build images-fast
virsh pool-start images-fast
virsh pool-autostart images-fast
echo "------------------检查结果------------------"
ls -la /var/lib/libvirt/
virsh pool-list --all

### 第七部分：节点定制收尾工作

# 设置SSH免密登录ads1，需要输入一次ads1的root密码，并上传rsa公钥到ads1上
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
ssh-copy-id -i /root/.ssh/id_rsa.pub bjape01-ads1
ssh bjape01-ads1 "rm -f /var/www/html/configfile/rsa-pub/*kvm01-root-id_rsa.pub"
scp /root/.ssh/id_rsa.pub bjape01-ads1:/var/www/html/configfile/rsa-pub/bjape01-kvm01-root-id_rsa.pub
echo "------------------检查结果------------------"
cat /root/.ssh/id_rsa.pub
ssh bjape01-ads1 "cat /var/www/html/configfile/rsa-pub/bjape01-kvm01-root-id_rsa.pub"

# 脚本自毁
rm -rf /root/shscript/syscus
echo "------------------检查结果------------------"
ls /root/shscript/

# 重启network服务
systemctl restart network
echo "------------------检查结果------------------"
sleep 5
ip addr | grep UP
