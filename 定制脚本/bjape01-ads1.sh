#!/bin/bash

# 说明：首先通过Cobbler Profile “CentOS7.4-x86_64-mini”，完成系统自动部署，然后执行本脚本完成cobbler安装及配置。因为中间涉及IP地址修改和输入密码的操作，所以本脚本只能在控制台执行。
# 注：本脚本适用于以下配置的服务器：
#     1、服务器为KVM虚拟机，其他虚拟化平台虚拟机未经验证。主要的差别在于网卡名称，在ESXi上的虚机，CentOS7/RHEL 7以上版本中，网卡名称为ens*；
#     2、创建虚机时OS选择RHEL 7.3；
#     3、创建虚机时网卡配置“桥接 br246”；
#     4、因兼做yum源服务器，故而硬盘空间要求大一些，至少100GB。硬盘要求用SCSI类型；

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
echo "------------------检查结果------------------"
cat /etc/hosts

# 设置主机名
echo 'bjape01-ads1' > /etc/hostname
hostname bjape01-ads1
echo "------------------检查结果------------------"
cat /etc/hostname

# 设置临时IP地址
echo 'TYPE=Ethernet
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=yes
NAME=eth0
DEVICE=eth0
ONBOOT=yes
IPADDR=172.16.246.200
NETMASK=255.255.255.0
GATEWAY=172.16.246.254
' > /etc/sysconfig/network-scripts/ifcfg-eth0
systemctl restart network
echo "------------------检查结果------------------"
cat /etc/sysconfig/network-scripts/ifcfg-eth0
ip addr | grep eth0

### 第二部分：设置用户环境

# 设置SSH免密登录
mkdir /root/.ssh
wget -q -O /root/ops11-id_rsa.pub http://cobbler/configfile/bjape01-ops11-root-id_rsa.pub
wget -q -O /root/ops12-id_rsa.pub http://cobbler/configfile/bjape01-ops12-root-id_rsa.pub
touch /root/.ssh/authorized_keys
cat /root/ops11-id_rsa.pub >> /root/.ssh/authorized_keys
cat /root/ops12-id_rsa.pub >> /root/.ssh/authorized_keys
rm -f /root/*id_rsa.pub
chown -R root:root /root/.ssh
chmod -R 600 /root/.ssh
echo "------------------检查结果------------------"
ls -la /root/.ssh
cat /root/.ssh/authorized_keys

# 设置SSH免密登录ads1，需要输入一次ads1的root密码
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
ssh-copy-id -i /root/.ssh/id_rsa.pub 172.16.246.1
echo "------------------检查结果------------------"
cat /root/.ssh/id_rsa.pub

### 第三部分：通用软件安装及配置，略过

### 第四部分：系统安全加固

# 调整root账号ssh登录源IP限制
sed -i 's/172.16.244.11 172.16.244.12/172.16.244.11 172.16.244.12 172.16.246.0\/24/g' /etc/security/access.conf
echo "------------------检查结果------------------"
tail /etc/security/access.conf

### 第五部分：节点定制系统优化，略过

### 第六部分：节点定制软件安装及配置

# 安装cobbler及其依赖rpm包
wget -q -O /root/apr-1.4.8-3.el7_4.1.x86_64.rpm http://cobbler/tools/cobbler2.8.2/apr-1.4.8-3.el7_4.1.x86_64.rpm
rpm -ivh /root/apr-1.4.8-3.el7_4.1.x86_64.rpm
yum -y install apr-util deltarpm libxml2-python libjpeg-turbo python-deltarpm createrepo
wget -q -O /root/httpd-tools-2.4.6-67.el7.centos.6.x86_64.rpm http://cobbler/tools/cobbler2.8.2/httpd-tools-2.4.6-67.el7.centos.6.x86_64.rpm
rpm -ivh /root/httpd-tools-2.4.6-67.el7.centos.6.x86_64.rpm
yum -y install tftp-server python-chardet python-kitchen yum-utils libyaml PyYAML jbigkit-libs libtiff python-backports python-backports-ssl_match_hostname python-setuptools libusal genisoimage libwebp python-pillow python-pygments
wget -q -O /root/python-markdown-2.4.1-2.el7.noarch.rpm http://cobbler/tools/cobbler2.8.2/python-markdown-2.4.1-2.el7.noarch.rpm
rpm -ivh /root/python-markdown-2.4.1-2.el7.noarch.rpm
wget -q -O /root/python-cheetah-2.4.4-5.el7.centos.x86_64.rpm http://cobbler/tools/cobbler2.8.2/python-cheetah-2.4.4-5.el7.centos.x86_64.rpm
rpm -ivh /root/python-cheetah-2.4.4-5.el7.centos.x86_64.rpm
yum -y install python-netaddr mtools syslinux rsync
wget -q -O /root/python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm http://cobbler/tools/cobbler2.8.2/python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm
rpm -ivh /root/python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm
wget -q -O /root/python-django-1.6.11.6-1.el7.noarch.rpm http://cobbler/tools/cobbler2.8.2/python-django-1.6.11.6-1.el7.noarch.rpm
rpm -ivh /root/python-django-1.6.11.6-1.el7.noarch.rpm
yum -y install mailcap
wget -q -O /root/httpd-2.4.6-67.el7.centos.6.x86_64.rpm http://cobbler/tools/cobbler2.8.2/httpd-2.4.6-67.el7.centos.6.x86_64.rpm
rpm -ivh /root/httpd-2.4.6-67.el7.centos.6.x86_64.rpm
yum -y install mod_wsgi
wget -q -O /root/mod_ssl-2.4.6-67.el7.centos.6.x86_64.rpm http://cobbler/tools/cobbler2.8.2/mod_ssl-2.4.6-67.el7.centos.6.x86_64.rpm
rpm -ivh /root/mod_ssl-2.4.6-67.el7.centos.6.x86_64.rpm
wget -q -O /root/python2-simplejson-3.10.0-1.el7.x86_64.rpm http://cobbler/tools/cobbler2.8.2/python2-simplejson-3.10.0-1.el7.x86_64.rpm
rpm -ivh /root/python2-simplejson-3.10.0-1.el7.x86_64.rpm
wget -q -O /root/cobbler-2.8.2-1.el7.x86_64.rpm http://cobbler/tools/cobbler2.8.2/cobbler-2.8.2-1.el7.x86_64.rpm
rpm -ivh /root/cobbler-2.8.2-1.el7.x86_64.rpm
wget -q -O /root/cobbler-web-2.8.2-1.el7.noarch.rpm http://cobbler/tools/cobbler2.8.2/cobbler-web-2.8.2-1.el7.noarch.rpm
rpm -ivh /root/cobbler-web-2.8.2-1.el7.noarch.rpm
yum -y install pykickstart tftp xinetd dhcp
rm -f /root/*.rpm

# 设置cobbler, 加密密码命令为：“openssl passwd -1 -salt 'salt' 'password'”
sed -i 's/default_password_crypted: "$1$mF86\/UHC$WvcIcX2t6crBz2onWxyac."/default_password_crypted: "$1$kgfjds$b.Nbn9AlXh5pF1.Ms1vER1"/g' /etc/cobbler/settings
sed -i 's/manage_dhcp: 0/manage_dhcp: 1/g' /etc/cobbler/settings
sed -i 's/manage_rsync: 0/manage_rsync: 1/g' /etc/cobbler/settings
sed -i 's/next_server: 127.0.0.1/next_server: 172.16.246.200/g' /etc/cobbler/settings
sed -i 's/restart_dns: 1/restart_dns: 0/g' /etc/cobbler/settings
sed -i 's/server: 127.0.0.1/server: 172.16.246.200/g' /etc/cobbler/settings
echo "------------------检查结果------------------"
grep default_password_crypted /etc/cobbler/settings
grep manage_dhcp /etc/cobbler/settings
grep manage_rsync /etc/cobbler/settings
grep "server: 1" /etc/cobbler/settings
grep restart_dns /etc/cobbler/settings

# 设置cobbler管理的DHCP服务模板
sed -i 's/subnet 192.168.1.0/subnet 172.16.246.0/g' /etc/cobbler/dhcp.template
sed -i 's/option routers             192.168.1.5/option routers             172.16.246.254/g' /etc/cobbler/dhcp.template
sed -i 's/option domain-name-servers 192.168.1.1/option domain-name-servers 202.106.0.20/g' /etc/cobbler/dhcp.template
sed -i 's/range dynamic-bootp        192.168.1.100 192.168.1.254/range dynamic-bootp        172.16.246.100 172.16.246.180/g' /etc/cobbler/dhcp.template
systemctl enable dhcpd
echo "------------------检查结果------------------"
head -n 25 /etc/cobbler/dhcp.template | tail -n 5

# 设置xinetd开机启动，并启动xinetd(用于tftp服务）
systemctl enable xinetd
systemctl start xinetd
echo "------------------检查结果------------------"
systemctl status xinetd

# 允许相关服务开机启动，并启动服务
systemctl enable rsyncd
systemctl start rsyncd
systemctl enable httpd
systemctl start httpd
systemctl enable cobblerd
systemctl start cobblerd
echo "------------------检查结果------------------"
systemctl status rsyncd
systemctl status httpd
systemctl status cobblerd

# 下载本地loader，代替执行命令：“cobbler get-loaders”
wget -q -O /var/lib/cobbler/loaders/COPYING.elilo http://cobbler/tools/cobbler2.8.2/loaders/COPYING.elilo
wget -q -O /var/lib/cobbler/loaders/COPYING.syslinux http://cobbler/tools/cobbler2.8.2/loaders/COPYING.syslinux
wget -q -O /var/lib/cobbler/loaders/COPYING.yaboot http://cobbler/tools/cobbler2.8.2/loaders/COPYING.yaboot
wget -q -O /var/lib/cobbler/loaders/elilo-ia64.efi http://cobbler/tools/cobbler2.8.2/loaders/elilo-ia64.efi
wget -q -O /var/lib/cobbler/loaders/grub-x86_64.efi http://cobbler/tools/cobbler2.8.2/loaders/grub-x86_64.efi
wget -q -O /var/lib/cobbler/loaders/grub-x86.efi http://cobbler/tools/cobbler2.8.2/loaders/grub-x86.efi
wget -q -O /var/lib/cobbler/loaders/menu.c32 http://cobbler/tools/cobbler2.8.2/loaders/menu.c32
wget -q -O /var/lib/cobbler/loaders/pxelinux.0 http://cobbler/tools/cobbler2.8.2/loaders/pxelinux.0
wget -q -O /var/lib/cobbler/loaders/README http://cobbler/tools/cobbler2.8.2/loaders/README
wget -q -O /var/lib/cobbler/loaders/yaboot http://cobbler/tools/cobbler2.8.2/loaders/yaboot
echo "------------------检查结果------------------"
ls /var/lib/cobbler/loaders

# 设置cobbler的web接口(https://172.16.246.1/cobbler_web)管理用户：admin，加密密码命令是：“htdigest /etc/cobbler/users.digest "Cobbler" admin”
echo 'admin:Cobbler:d0976fab0ee2a0f7df595d909d835918' > /etc/cobbler/users.digest
echo "------------------检查结果------------------"
cat /etc/cobbler/users.digest

# 同步cobbler配置，并检查
systemctl restart cobblerd
sleep 10
cobbler sync
echo "
------------------检查结果------------------"
cobbler check

# 同步cobbler上公用资源
echo "
-----------cobbler公用资源同步--------------"
rsync -av --bwlimit=51200 172.16.246.1:/var/www/html/ /var/www/html/
rsync -av 172.16.246.1:/var/lib/cobbler/kickstarts/ /var/lib/cobbler/kickstarts/
echo "
------------------检查结果------------------"
tree -a /var/www/html

# 向cobbler中导入ISO，并增加profile、删除自动添加的无用profile
echo "
------------导入CentOS 7.4 x64--------------"
mount /var/www/html/iso/CentOS-7-x86_64-Everything-1708.iso /media
cobbler import --path=/media --name=CentOS7.4 --arch=x86_64
umount /media
echo "
------------导入OracleLinux 6.8-------------"
mount /var/www/html/iso/OracleLinux-R6-U8-Server-x86_64-dvd.iso /media
cobbler import --path=/media --name=OracleLinux6.8
umount /media
echo "
------------导入RHEL 7.3 x64----------------"
mount /var/www/html/iso/rhel-server-7.3-x86_64-dvd.iso /media
cobbler import --path=/media --name=RHEL7.3 --arch=x86_64
umount /media
echo "
------------导入RHEL 5.10 x64---------------"
mount /var/www/html/iso/rhel-server-5.10-x86_64-dvd.iso /media
cobbler import --path=/media --name=RHEL5.10 --arch=x86_64
umount /media
echo "
---------------增加profile------------------"
cobbler profile add --name=1-RHEL7.3-x86_64-kvm  --distro=RHEL7.3-x86_64 --kickstart=/var/lib/cobbler/kickstarts/rhel7.3-kvm.ks
cobbler profile add --name=2-RHEL7.3-x86_64-mini  --distro=RHEL7.3-x86_64 --kickstart=/var/lib/cobbler/kickstarts/rhel7.3-mini.ks
cobbler profile add --name=3-CentOS7.4-x86_64-mini --distro=CentOS7.4-x86_64 --kickstart=/var/lib/cobbler/kickstarts/centos7.4-mini.ks
cobbler profile add --name=4-OracleLinux6.8-x86_64-oracledb --distro=OracleLinux6.8-x86_64 --kickstart=/var/lib/cobbler/kickstarts/ol6.8-oracledb.ks
cobbler profile add --name=RHEL7.3-Rescue-Mode --distro=RHEL7.3-x86_64 --kickstart=/var/lib/cobbler/kickstarts/pxerescue.ks
cobbler profile add --name=RHEL5.10-x86_64-mini  --distro=RHEL5.10-x86_64 --kickstart=/var/lib/cobbler/kickstarts/rhel5.10-mini.ks
echo "
---------------删除profile------------------"
cobbler profile remove --name=OracleLinux6.8-i386
cobbler profile remove --name=RHEL5.10-xen-x86_64

# 检查cobbler配置结果
echo "
----------------检查cobbler-----------------"
cobbler sync
cobbler distro list
cobbler profile list
cat /var/lib/cobbler/kickstarts/pxerescue.ks

# 修改cobbler服务器IP地址为正式地址
sed -i 's/172.16.246.200/172.16.246.1/g' /etc/sysconfig/network-scripts/ifcfg-eth0
echo "
------------ifcfg-eth0检查结果--------------"
cat /etc/sysconfig/network-scripts/ifcfg-eth0

# 修改cobbler相关配置中的地址为正式地址
sed -i 's/172.16.246.200/172.16.246.1/g' /etc/cobbler/settings
sed -i 's/next-server                172.16.246.200/next-server                172.16.246.1/g' /etc/dhcp/dhcpd.conf
sed -i 's/172.16.246.200/172.16.246.1/g' /var/lib/tftpboot/grub/efidefault
sed -i 's/172.16.246.200/172.16.246.1/g' /var/lib/tftpboot/pxelinux.cfg/default
echo "
----------------最后检查结果----------------"
echo "
-----------/etc/cobbler/settings------------"
grep "server: 1" /etc/cobbler/settings
echo "
-----------/etc/dhcp/dhcpd.conf-------------"
head -n 26 /etc/dhcp/dhcpd.conf | tail -n 8
echo "
-----/var/lib/tftpboot/grub/efidefault------"
grep 172.16.246 /var/lib/tftpboot/grub/efidefault
echo "
---/var/lib/tftpboot/pxelinux.cfg/default---"
grep 172.16.246 /var/lib/tftpboot/pxelinux.cfg/default
echo "
-----------------ip addr---------------------"
ip addr | grep eth0

### 第七部分：节点定制收尾工作

# 脚本自毁
rm -rf /root/shscript/syscus
echo "------------------检查结果------------------"
ls /root/shscript/
