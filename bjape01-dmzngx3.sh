#!/bin/bash

# 说明：首先通过Cobbler Profile “RHEL7.3-x86_64-mini”，完成系统自动部署，然后执行本脚本完成bjape01-dmzngx3安装及配置。因为中间涉及IP地址修改，所以本脚本只能在控制台或后台执行。
# 因为要建立三节点的高可用集群，集群管理的命令在本节点执行即可，但需要另外的两个节点先完成节点定制并重启。
# 
# 注：本脚本适用于以下配置的服务器：
#     1、服务器为ESXi或KVM虚拟机，其他虚拟化平台虚拟机未经验证；
#     2、创建虚机时OS选择RHEL 7.3；
#     3、创建虚机时只需配置一块网卡，网卡首先配置“桥接br246”，等安装完成后再改成“br3”；
#     4、硬盘要求用SCSI类型。创建虚机时只配置一块硬盘，大小不限；
#     5、通过pacemaker提供高可用的三节点nginx集群。

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
clusterName=dmzngx
node1=dmzngx1
node2=dmzngx2
node3=dmzngx3
VIP=172.16.223.30
node1IP=172.16.223.31
node2IP=172.16.223.32
node3IP=172.16.223.33
gateway=172.16.223.254
netIf=`ip a | grep 172.16.246 | awk '{printf $8}'`

localNode=${node3}
localIP=${node3IP}

initPWD=58858547

rootDir=/root

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
${VIP}     ${env}-${clusterName}
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
mkdir /root/.ssh
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

# 调整root账号ssh登录源IP限制
sed -i 's/172.16.244.11/172.16.2.250 172.16.244.11/g' /etc/security/access.conf
sed -i 's/172.16.244.12/172.16.244.12 172.16.245.3/g' /etc/security/access.conf
echo "------------------检查结果------------------"
tail /etc/security/access.conf

### 第五部分：节点定制系统优化

### 第六部分：节点定制软件安装及配置

# 编译安装nginx
useradd -s /sbin/nologin -M nginx
mkdir /var/cache/nginx
cd ${rootDir}
wget -q http://cobbler/tools/nginx/nginx-1.12.1.tar.gz
tar -zxvf nginx-1.12.1.tar.gz
wget -q http://cobbler/tools/nginx/naxsi-master.zip
unzip naxsi-master.zip
wget -q http://cobbler/tools/nginx/08a395c66e42.zip
unzip 08a395c66e42.zip
mv nginx-goodies-nginx-sticky-module-ng-08a395c66e42 nginx-sticky
cd nginx-1.12.1
./configure --add-module=${rootDir}/naxsi-master/naxsi_src/ --add-module=${rootDir}/nginx-sticky/ --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'
make && make install
cd ${rootDir}
rm -rf nginx-1.12.1*
rm -rf nginx-sticky
rm -rf naxsi-master
rm -rf *.zip
echo "------------------检查结果------------------"
nginx -V

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
