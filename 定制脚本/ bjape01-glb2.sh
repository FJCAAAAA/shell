#!/bin/bash

# 说明：首先通过Cobbler Profile “RHEL7.3-x86_64-mini”，完成系统自动部署，然后执行本脚本完成bjape01-glb2安装及配置。因为中间涉及IP地址修改，所以本脚本只能在控制台或后台执行。
# 因为要建立三节点的高可用集群，集群管理的命令在第一节点执行即可，但需要本节点先完成节点定制。
# 
# 注：本脚本适用于以下配置的服务器：
#     1、服务器为ESXi或KVM虚拟机，其他虚拟化平台虚拟机未经验证；
#     2、创建虚机时OS选择RHEL 7.3；
#     3、创建虚机时只需配置一块网卡，网卡首先配置“桥接br246”，等安装完成后再改成“br227”；
#     4、硬盘要求用SCSI类型。创建虚机时只配置一块硬盘，大小不限；
#     5、通过pacemaker提供高可用的三节点haproxy集群。

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

# 设置全局变量
env=bjape01
node1=glb1
node2=glb2
node3=glb3
VIP=172.16.227.10
node1IP=172.16.227.11
node2IP=172.16.227.12
node3IP=172.16.227.13
gateway=172.16.227.254
netIf=`ip a | grep 172.16.246 | awk '{printf $8}'`

localNode=${node2}
localIP=${node2IP}

initPWD=58858547

# 下载环境对应Banner文件
rm -f /etc/motd
wget -q -O /etc/motd http://cobbler/configfile/motd/${env}-motd
echo "------------------检查结果------------------"
cat /etc/motd

# 设置hosts文件
sed -i "s/ads1/${env}-ads1/g" /etc/hosts
sed -i "s/ms20/${env}-ms20/g" /etc/hosts
echo "# localhost
${localIP}      ${env}-${localNode}

# Global Load Balance Cluster
${VIP}     ${env}-glb
${node1IP}     ${env}-${node1}
${node2IP}     ${env}-${node2}
${node3IP}     ${env}-${node3}
" | tee -a /etc/hosts
echo "------------------检查结果------------------"
cat /etc/hosts

# 设置主机名
hostnamectl set-hostname ${env}-${localNode}
echo "------------------检查结果------------------"
cat /etc/hostname

# 设置高可用组件yum源
echo '
[rhel-ha]
name=Red Hat Enterprise Linux 7.3 HighAvailability 
baseurl=http://cobbler/cobbler/ks_mirror/RHEL7.3-x86_64/addons/HighAvailability
enabled=1
gpgcheck=0
cost=1
' >> /etc/yum.repos.d/local.repo
echo "----------------result check----------------"
cat /etc/yum.repos.d/local.repo

# 设置正式IP地址，并配置子接口用于继续安装
echo "TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
NAME=${netIf}
DEVICE=${netIf}
ONBOOT=yes
IPADDR=${localIP}
NETMASK=255.255.255.0
GATEWAY=${gateway}
" > /etc/sysconfig/network-scripts/ifcfg-${netIf}
echo "TYPE=Ethernet
BOOTPROTO=dhcp
IPV4_FAILURE_FATAL=yes
NAME=${netIf}:1
DEVICE=${netIf}:1
ONBOOT=yes
" > /etc/sysconfig/network-scripts/ifcfg-${netIf}:1
ps aux | grep dhclient | grep -v grep | awk '{print $2}' | xargs kill -9
systemctl restart network
ifup ${netIf}:1
echo "------------------检查结果------------------"
cat /etc/sysconfig/network-scripts/ifcfg-${netIf}
cat /etc/sysconfig/network-scripts/ifcfg-${netIf}:1
ip addr | grep ${netIf}

### 第二部分：设置用户环境

# 设置SSH免密登录
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
wget -q -O /root/ops11-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops11-root-id_rsa.pub
wget -q -O /root/ops12-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops12-root-id_rsa.pub
wget -q -O /root/ops11-supope-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops11-supope-id_rsa.pub
wget -q -O /root/ops12-supope-id_rsa.pub http://cobbler/configfile/rsa-pub/${env}-ops12-supope-id_rsa.pub
touch /root/.ssh/authorized_keys
cat /root/ops11-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/ops12-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/ops11-supope-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/ops12-supope-id_rsa.pub >> /root/.ssh/authorized_keys
rm -f /root/*id_rsa.pub
chown -R root:root /root/.ssh
chmod -R 600 /root/.ssh
echo "------------------检查结果------------------"
ls -la /root/.ssh
cat /root/.ssh/authorized_keys

### 第三部分：通用软件安装及配置

# 安装高可用套件
yum -y install pacemaker pcs fence-agents-all

# 配置pcsd服务
echo ${initPWD} | passwd --stdin hacluster
systemctl enable pcsd
systemctl start pcsd
echo "------------------检查结果------------------"
systemctl status pcsd

### 第四部分：系统安全加固

### 第五部分：节点定制系统优化

### 第六部分：节点定制软件安装及配置

# 编译安装及配置haproxy
useradd haproxy
wget -q -O /root/haproxy.tar.gz http://cobbler/tools/haproxy-1.6.2.tar.gz
tar zxvf /root/haproxy.tar.gz
cd /root/haproxy-1.6.2
make TARGET=linux2628 PREFIX=/usr/local/haproxy
make install TARGET=linux2628 PREFIX=/usr/local/haproxy
cd ~
rm -rf /root/haproxy*
mkdir /usr/local/haproxy/workspace /var/lib/haproxy
wget -q -O /usr/local/haproxy/haproxy.cfg http://cobbler/configfile/haproxy.cfg
cp /usr/local/haproxy/sbin/haproxy /usr/sbin
wget -q -O /etc/rc.d/init.d/haproxy http://cobbler/shscript/service/haproxy
chmod 755 /etc/rc.d/init.d/haproxy
chkconfig haproxy on
service haproxy start
echo "------------------检查结果------------------"
chkconfig --list haproxy
systemctl status haproxy

# 配置日志输出
echo "local3.*                                                /var/log/haproxy.log" >> /etc/rsyslog.conf
sed -i 's/^#$ModLoad imudp/$ModLoad imudp/g' /etc/rsyslog.conf
sed -i 's/^#$UDPServerRun 514/$UDPServerRun 514/g' /etc/rsyslog.conf
systemctl restart rsyslog
systemctl restart haproxy
echo "------------------检查结果------------------"
ls -la /var/log/haproxy.log
tail /var/log/haproxy.log
service haproxy checkconfig

# 添加haproxy监控项
wget -q -O /root/socat.tar.gz http://cobbler/tools/socat-1.7.3.2.tar.gz
tar zxvf /root/socat.tar.gz
cd /root/socat-1.7.3.2
./configure
make && make install
cd ~
rm -rf /root/socat*

cd /usr/local/nagios/libexec/
wget -q -nd -r -l1 --no-parent http://cobbler/shscript/nagios/
rm -rf ./index.html*
chmod +x ./check*
chown -R nagios.nagios ./*
cd ~

echo "
#check reverse proxy service port
command[check_tcp_8080]=/usr/local/nagios/libexec/check_tcp -H ${VIP} -p 8080
#check reverse proxy service status
command[check_web8081_status]=/usr/local/nagios/libexec/check_web8081_status -H ${VIP}
#check vip
command[check_vip]=/usr/local/nagios/libexec/check_vip
#check haproxy status
command[check_haproxy_sc]=/usr/local/nagios/libexec/check_haproxy_sc
command[check_haproxy_msc]=/usr/local/nagios/libexec/check_haproxy_msc
command[check_haproxy_denied]=/usr/local/nagios/libexec/check_haproxy_denied
command[check_haproxy_errors]=/usr/local/nagios/libexec/check_haproxy_errors
command[check_haproxy_warings]=/usr/local/nagios/libexec/check_haproxy_warings
command[check_haproxy_flow]=/usr/local/nagios/libexec/check_haproxy_flow
" >> /usr/local/nagios/etc/nrpe.cfg
echo "------------------检查结果------------------"
tail -n 15 /usr/local/nagios/etc/nrpe.cfg
ls -la /usr/local/nagios/libexec/

### 第七部分：节点定制收尾工作

# 删除临时网卡子接口
ifdown ${netIf}:1
rm -f /etc/sysconfig/network-scripts/ifcfg-${netIf}:1
echo "------------------检查结果------------------"
ls /etc/sysconfig/network-scripts/ifcfg-${netIf}*

# 脚本自毁
rm -rf /root/shscript/syscus
echo "------------------检查结果------------------"
ls /root/shscript/

# 重启系统
init 6
