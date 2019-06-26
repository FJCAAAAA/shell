#!/bin/bash

# 说明：首先通过Cobbler Profile “OracleLinux6.8-x86_64-oracledb”，完成系统自动部署，然后执行本脚本完成bjape01-sumapay安装及配置。因为中间涉及IP地址修改，所以本脚本只能在控制台或后台执行。
# # 注：本脚本适用于以下配置的服务器：
#     1、服务器为ESXi或KVM虚拟机，其他虚拟化平台虚拟机未经验证；
#     2、创建虚机时OS选择RHEL 6.8；
#     3、创建虚机时只需配置一块网卡，网卡首先配置“桥接br246”，等安装完成后再改成“桥接br219”；
#     4、虚机需要配置三块硬盘，硬盘要求用SCSI类型。创建虚机时只配置一块硬盘，大小不限。第二、三块硬盘要求在创建完虚机后手动添加。如果是ESXi虚机，其中第二块硬盘的容量不小于400GB，第三块硬盘的容量不小于50GB。并且需要安装VMware Tools并设置参数disk.enableUUID=true；如果是KVM虚机，两块硬盘的容量需要互换。这两块硬盘对应脚本中的ASM磁盘data(asm-diskb)、fra(asm-diskc)；
#     5、如果是ESXi虚机，完成系统自动部署后，执行本脚本前需完成以下步骤：
#        a、右击虚机，选“客户机”—>“安装/升级 VMware Tools”；
#        b、通过控制台登录虚机，执行下面的命令：
#               mkdir vmware-tools
#               cd vmware-tools/
#               cp -r /media/VMware\ Tools/* ./
#               tar zxvf VMwareTools-*.tar.gz
#               cd vmware-tools-distrib/
#               perl vmware-install.pl
#           按照安装提示一步步操作，保持缺省值即可。安装完成后关闭虚机；
#        c、虚机关闭后，右击虚机，选“编辑设置”—>“选项”—>“常规”—>“配置参数”—>“添加行”，然后在“名称”栏输入：disk.enableUUID，“值”输入：true。保存退出，然后将虚机加电。

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
dbName=sumapay
node1=sumapay
node2=dg1
node3=dg2
node4=dg3
node5=rman1
node6=rman2
node7=warehouse
VIP=172.16.219.99
node1IP=172.16.219.99
node2IP=172.16.219.101
node3IP=172.16.219.201
node4IP=172.16.219.102
node5IP=172.16.219.106
node6IP=172.16.219.206
node7IP=172.16.219.104
gateway=172.16.219.254
netIf=`ip a | grep 172.16.246 | awk '{printf $7}'`

localNode=${node1}
localIP=${node1IP}

# 下载环境对应Banner文件
rm -f /etc/motd
wget -q -O /etc/motd http://cobbler/configfile/motd/${env}-motd
echo "------------------检查结果------------------"
cat /etc/motd

# 设置hosts文件
sed -i "s/ads1/${env}-ads1/g" /etc/hosts
sed -i "s/ms20/${env}-ms20/g" /etc/hosts
echo "#  localhost
${localIP}      ${env}-${localNode}

# oracle DB server
${VIP}     ${node1}
${node1IP}     ${env}-${node1}
${node2IP}     ${env}-${node2}
${node3IP}     ${env}-${node3}
${node4IP}     ${env}-${node4}
${node5IP}     ${env}-${node5}
${node6IP}     ${env}-${node6}
${node7IP}     ${env}-${node7}
" | tee -a /etc/hosts
echo "------------------检查结果------------------"
cat /etc/hosts

# 设置主机名
sed -i "s/HOSTNAME=localhost.localdomain/HOSTNAME=${env}-${localNode}/g" /etc/sysconfig/network
echo "------------------检查结果------------------"
cat /etc/sysconfig/network

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
service network restart
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

### 第三部分：通用软件安装及配置，略过

### 第四部分：系统安全加固，略过

### 第五部分：节点定制系统优化

# 用于oracle preinstall的系统参数调优
echo '
# oracle-rdbms-server-11gR2-preinstall setting for nofile soft limit is 1024
grid   soft   nofile    1024

# oracle-rdbms-server-11gR2-preinstall setting for nofile hard limit is 65536
grid   hard   nofile    65536

# oracle-rdbms-server-11gR2-preinstall setting for nproc soft limit is 2047
grid   soft   nproc    2047

# oracle-rdbms-server-11gR2-preinstall setting for nproc hard limit is 16384
grid   hard   nproc    16384

# oracle-rdbms-server-11gR2-preinstall setting for stack soft limit is 10240KB
grid   soft   stack    10240

# oracle-rdbms-server-11gR2-preinstall setting for stack hard limit is 32768KB
grid   hard   stack    32768
' >> /etc/security/limits.conf
ulimit -s unlimited
echo "------------------检查结果------------------"
ulimit -a

# 修改本地服务端口
echo '9000 65500' > /proc/sys/net/ipv4/ip_local_port_range
echo "------------------检查结果------------------"
cat /proc/sys/net/ipv4/ip_local_port_range

### 第六部分：节点定制软件安装及配置

echo "----------oracle数据库安装前准备------------"

# 创建Oracle和Grid用户及相关用户组
groupadd -g 1000 oinstall
groupadd -g 1020 asmadmin
groupadd -g 1021 asmdba
groupadd -g 1022 asmoper
groupadd -g 1031 dba
groupadd -g 1032 oper
useradd -m -u 1100 -g oinstall -G asmadmin,asmdba,asmoper,oper,dba -d /home/grid -s /bin/bash -c "Grid Infrastructure Owner" -p "grid" grid
echo 'grid:grid' | chpasswd
useradd -m -u 1101 -g oinstall -G dba,oper,asmdba -d /home/oracle -s /bin/bash -c "Oracle Software Owner" -p "oracle" oracle
echo 'oracle:oracle' | chpasswd
echo "------------------检查结果------------------"
tail /etc/passwd
tail /etc/group

# 创建Oracle基本目录
mkdir -p /u01/app/grid
chown grid:oinstall /u01/app/grid
mkdir -p /u01/app/11.2.0/grid
chown -R grid:oinstall /u01/app/11.2.0/grid
mkdir -p /u01/app/oraInventory
chown grid:oinstall /u01/app/oraInventory
mkdir -p /u01/app/oracle
chown oracle:oinstall /u01/app/oracle
chmod -R 775 /u01/
echo "------------------检查结果------------------"
ls -la /u01/app

# 安装oracle安装准备工具
yum -y install oracleasm-support oracle-rdbms-server-11gR2-preinstall

# 下载oracle安装软件并解压
echo "Begin download p13390677_112040_Linux-x86-64_1of7.zip"
wget -q -c -t 100 -T 120 -O /u01/p13390677_112040_Linux-x86-64_1of7.zip http://cobbler/tools/oracle/p13390677_112040_Linux-x86-64_1of7.zip
echo "Finished download p13390677_112040_Linux-x86-64_1of7.zip"

echo "Begin download p13390677_112040_Linux-x86-64_2of7.zip"
wget -q -c -t 100 -T 120 -O /u01/p13390677_112040_Linux-x86-64_2of7.zip http://cobbler/tools/oracle/p13390677_112040_Linux-x86-64_2of7.zip
echo "Finished download p13390677_112040_Linux-x86-64_2of7.zip"

echo "Begin download p13390677_112040_Linux-x86-64_3of7.zip"
wget -q -c -t 100 -T 120 -O /u01/p13390677_112040_Linux-x86-64_3of7.zip http://cobbler/tools/oracle/p13390677_112040_Linux-x86-64_3of7.zip
echo "Finished download p13390677_112040_Linux-x86-64_3of7.zip"

unzip /u01/p13390677_112040_Linux-x86-64_1of7.zip -d /u01/
unzip /u01/p13390677_112040_Linux-x86-64_2of7.zip -d /u01/
unzip /u01/p13390677_112040_Linux-x86-64_3of7.zip -d /u01/
chown -R grid:oinstall /u01/grid
chown -R oracle:oinstall /u01/database/
rm -f /u01/p13390677_112040_Linux-x86-64_*.zip
echo "------------------检查结果------------------"
ls -la /u01/

# 安装ssh密码工具
wget -q -O /root/sshpass-1.05.tar.gz http://cobbler/tools/sshpass-1.05.tar.gz
tar -zxvf /root/sshpass-1.05.tar.gz
cd sshpass-1.05
./configure
make && make install
cd
rm -rf /root/sshpass*

# 设置用户Grid环境变量
echo 'ORACLE_SID=+ASM; export ORACLE_SID
JAVA_HOME=/usr/local/java; export JAVA_HOME
ORACLE_BASE=/u01/app/grid; export ORACLE_BASE
ORACLE_HOME=/u01/app/11.2.0/grid; export ORACLE_HOME
ORACLE_PATH=/u01/app/oracle/common/oracle/sql; export ORACLE_PATH
ORACLE_TERM=xterm; export ORACLE_TERM
LANG=en_US; export LANG
NLS_LANG=AMERICAN_AMERICA.ZHS16GBK; export NLS_LANG
NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"; export NLS_DATE_FORMAT

PATH=.:${JAVA_HOME}/bin:${PATH}:${HOME}/bin:${ORACLE_HOME}/bin
PATH=${PATH}:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin
PATH=${PATH}:/u01/app/common/oracle/bin
export PATH

LD_LIBRARY_PATH=${ORACLE_HOME}/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${ORACLE_HOME}/oracm/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH

CLASSPATH=${ORACLE_HOME}/JRE
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/jlib
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/rdbms/jlib
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/network/jlib
export CLASSPATH

THREADS_FLAG=native; export THREADS_FLAG
export TEMP=/tmp
export TMPDIR=/tmp
umask 022

DISPLAY=:0.0; export DISPLAY
' >> /home/grid/.bash_profile
su - grid -c 'source /home/grid/.bash_profile'
echo "------------------检查结果------------------"
su - grid -c 'set | grep ORACLE'
su - grid -c 'set | grep JAVA'
su - grid -c 'set | grep PATH'
su - grid -c 'set | grep NLS'
su - grid -c 'set | grep tmp'

# 设置用户Oracle环境变量
echo 'ORACLE_SID=sumapay; export ORACLE_SID
ORACLE_HOSTNAME=${HOSTNAME}; export ORACLE_HOSTNAME
ORACLE_UNQNAME=sumapay; export ORACLE_UNQNAME
JAVA_HOME=/usr/local/java; export JAVA_HOME
ORACLE_BASE=/u01/app/oracle; export ORACLE_BASE
ORACLE_HOME=${ORACLE_BASE}/product/11.2.0/db_1; export ORACLE_HOME
ORACLE_TERM=xterm; export ORACLE_TERM
LANG=en_US; export LANG
NLS_LANG=AMERICAN_AMERICA.ZHS16GBK; export NLS_LANG
NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"; export NLS_DATE_FORMAT

PATH=.:${JAVA_HOME}/bin:${PATH}:${HOME}/bin:${ORACLE_HOME}/bin
PATH=${PATH}:/usr/bin:/bin:/usr/bin/X11:/usr/local/bin
PATH=${PATH}:/u01/app/common/oracle/bin
export PATH

LD_LIBRARY_PATH=${ORACLE_HOME}/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${ORACLE_HOME}/oracm/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH

CLASSPATH=${ORACLE_HOME}/JRE
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/jlib
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/rdbms/jlib
CLASSPATH=${CLASSPATH}:${ORACLE_HOME}/network/jlib
export CLASSPATH

THREADS_FLAG=native; export THREADS_FLAG
export TEMP=/tmp
export TMPDIR=/tmp
umask 022

DISPLAY=:0.0; export DISPLAY
' >> /home/oracle/.bash_profile
su - oracle -c 'source /home/oracle/.bash_profile'
echo "------------------检查结果------------------"
su - oracle -c 'set | grep ORACLE'
su - oracle -c 'set | grep JAVA'
su - oracle -c 'set | grep PATH'
su - oracle -c 'set | grep NLS'
su - oracle -c 'set | grep tmp'

# 使用udev配置ASM磁盘（ESXi虚机需设置: disk.enableUUID=true）
DISKB=`lsblk -b | grep sdb | awk '{print $4}' | grep -o "[0-9]\{1,\}" | head -n 1`
DISKC=`lsblk -b | grep sdc | awk '{print $4}' | grep -o "[0-9]\{1,\}" | head -n 1`
DISKB=$(( ${DISKB} / ( 1024 * 1024 * 1024 ) - 5 ))
DISKC=$(( ${DISKC} / ( 1024 * 1024 * 1024 ) - 2 ))

touch /etc/udev/rules.d/99-oracle-asmdevices.rules
for i in b c
do
echo "KERNEL==\"sd*\", BUS==\"scsi\", PROGRAM==\"/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/\$name\", RESULT==\"`/sbin/scsi_id --whitelisted --replace-whitespace --device=/dev/sd$i`\", NAME=\"asm-disk$i\", OWNER=\"grid\", GROUP=\"asmadmin\", MODE=\"0660\"" >> /etc/udev/rules.d/99-oracle-asmdevices.rules
done

sed -i 's/dev\/", RESULT/dev\/\$name", RESULT/g' /etc/udev/rules.d/99-oracle-asmdevices.rules

/sbin/udevadm control --reload-rules
ps aux | grep udev | grep -v grep | awk '{print $2}' | xargs kill -9
/sbin/start_udev
echo "------------------检查结果------------------"
cat /etc/udev/rules.d/99-oracle-asmdevices.rules
ls -la /dev/asm*
echo ${DISKB}
echo ${DISKC}

# 安装cvuqdisk
rpm -ivh /u01/grid/rpm/cvuqdisk-1.0.9-1.rpm

echo "-------------oracle数据库安装---------------"

# 使用grid用户安装grid infrastructure
echo "**************GI软件安装开始****************"

export LANG=en_US.UTF-8
rm -rf /tmp/OraInstall*
wget -q -O /home/grid/grid.rsp http://cobbler/configfile/oracle/grid.rsp
sed -i "s/^ORACLE_HOSTNAME=/ORACLE_HOSTNAME=${env}-${localNode}/" /home/grid/grid.rsp
chown grid:oinstall /home/grid/grid.rsp
su - grid -c '
/u01/grid/runInstaller -silent -ignoreSysPrereqs -ignorePrereq -showProgress -responseFile "/home/grid/grid.rsp"
# 检查GI软件安装完成
for i in $(seq 1 150);
do
echo "等待runInstaller安装完成，第$i次检查"
sleep 10
[ "`ls /tmp/ | grep OraInstall`" == "" ] && break
done
echo "runInstaller安装完成！"
'

# 设置oracle开机启动
echo '#start oracle
start on runlevel [35]
stop on runlevel [016]
respawn
exec /etc/init.d/init.ohasd run >/dev/null 2>&1 </dev/null
' > /etc/init/init-orahas.conf
echo "------------------检查结果------------------"
cat /etc/init/init-orahas.conf

# sys、asmsnmp密码:password
# Execute Root Scripts in progress.
# As a root user, execute the following script(s):
# <执行root>        1. /u01/app/oraInventory/orainstRoot.sh
# <执行root>        2. /u01/app/11.2.0/grid/root.sh
#
# Execute /u01/app/oraInventory/orainstRoot.sh on the following nodes:
# [local]
/u01/app/oraInventory/orainstRoot.sh

# Execute /u01/app/11.2.0/grid/root.sh on the following nodes:
# [local]
/u01/app/11.2.0/grid/root.sh

# As install user, execute the following script. to complete the configuration.
# Note:
#     1. This script. must be run on the same system from where installer was run.
#     2. This script. needs a small password properties file for configuration assistants that require passwords (refer to install guide documentation).
# 只在安装grid程序的节点上执行一次，所有集群节点都会配置完成
# <执行grid> /u01/app/11.2.0/grid/cfgtoollogs/configToolAllCommands RESPONSE_FILE=<response_file>
#
wget -q -O /u01/app/11.2.0/grid/cfgtoollogs/cfgrsp.properties http://cobbler/configfile/oracle/cfgrsp.properties
chown grid:oinstall /u01/app/11.2.0/grid/cfgtoollogs/cfgrsp.properties
su - grid -c '/u01/app/11.2.0/grid/cfgtoollogs/configToolAllCommands RESPONSE_FILE=/u01/app/11.2.0/grid/cfgtoollogs/cfgrsp.properties'
su - grid -c  "crsctl start res ora.cssd"
su - grid -c  "crsctl status res ora.cssd"
su - grid -c  "srvctl add asm -l LISTENER -p /u01/app/11.2.0/grid/dbs/init+ASM.ora -d '/dev/asm*'"
sleep 10
su - grid -c  "srvctl start asm"

# init ASMSNMP password and privileges
su - grid -c 'orapwd file=/u01/app/11.2.0/grid/dbs/orapw+ASM password=password entries=10'
su - grid -c 'sqlplus / as sysasm'<<EOF
create user asmsnmp identified by password;
grant sysasm to sys;
grant sysdba to asmsnmp;
select * from V\$PWFILE_USERS;
quit;
EOF

# GI软件安装完成，检查集群服务的启动情况
echo "------------------检查结果------------------"
ifconfig
netstat -nlt | grep :1521
ps -ef | grep pmon
su - grid -c 'crsctl check has'
su - grid -c 'crsctl check evm'
su - grid -c 'crs_stat -t'
su - grid -c 'srvctl config asm -a'
su - grid -c 'crsctl stat res -t'
su - grid -c 'crsctl stat res -t -init'
su - grid -c 'ocrcheck'

echo "*************GI软件安装结束*****************"

echo "************DISKGROUP创建开始***************"

su - grid -c 'sqlplus / as sysasm'<<EOF
select group_number,name,state from v\$asm_diskgroup;
select NAME,ALLOCATION_UNIT_SIZE,STATE,TYPE,TOTAL_MB,
   FREE_MB,REQUIRED_MIRROR_FREE_MB,USABLE_FILE_MB
   from V\$ASM_DISKGROUP;
quit;
EOF

# 本机执行
su - grid -c 'sqlplus / as sysasm'<<EOF
select group_number,name,state,TOTAL_MB,FREE_MB from v\$asm_diskgroup;
CREATE DISKGROUP DATA EXTERNAL REDUNDANCY
   DISK '/dev/asm-diskb' SIZE ${DISKB}G
   ATTRIBUTE 'compatible.asm'='11.2.0.0.0','au_size'='1M';
--alter diskgroup DATA mount;
select group_number,name,state,TOTAL_MB,FREE_MB from v\$asm_diskgroup;
quit;
EOF

# 本机执行
su - grid -c 'sqlplus / as sysasm'<<EOF
select group_number,name,state,TOTAL_MB,FREE_MB from v\$asm_diskgroup;
CREATE DISKGROUP FRA EXTERNAL REDUNDANCY
   DISK '/dev/asm-diskc' SIZE ${DISKC}G
   ATTRIBUTE 'compatible.asm'='11.2.0.0.0','au_size'='1M';
--alter diskgroup FRA mount;
select group_number,name,state,TOTAL_MB,FREE_MB from v\$asm_diskgroup;
quit;
EOF

echo "************DISKGROUP创建结束***************"

echo "**************DB软件安装开始****************"

rm -rf /tmp/OraInstall*
wget -q -O /home/oracle/db.rsp http://cobbler/configfile/oracle/db.rsp
sed -i "s/^ORACLE_HOSTNAME=/ORACLE_HOSTNAME=${env}-${localNode}/" /home/oracle/db.rsp
chown oracle:oinstall /home/oracle/db.rsp
su - oracle -c '/u01/database/runInstaller -silent -ignoreSysPrereqs -ignorePrereq -showProgress -printdiskusage -printmemory -printtime -responseFile "/home/oracle/db.rsp"
# 检查DB软件安装完成
for i in $(seq 1 90);
do
echo "等待runInstaller安装完成，第$i次检查"
sleep 10
[ "`ls /tmp/ | grep OraInstall`" == "" ] && break
done
echo "runInstaller安装完成！"
'

# <执行root> /u01/app/oracle/product/11.2.0/db_1/root.sh
sh /u01/app/oracle/product/11.2.0/db_1/root.sh

# DB软件安装完成，检查集群服务的启动情况
ifconfig
netstat -nlt | grep :1521
su - grid -c 'crsctl stat res -t'
su - grid -c "srvctl status database -d ${dbName}"
su - grid -c "srvctl config database -d ${dbName} -a"
su - grid -c 'srvctl status asm'
su - grid -c 'srvctl config asm -a'
su - grid -c 'srvctl status listener'
su - grid -c 'srvctl config listener'

echo "**************DB软件安装结束****************"

echo "******DB实例创建开始（只需在节点1执行）*****"

wget -q -O /home/oracle/dbca.rsp http://cobbler/configfile/oracle/dbca.rsp
sed -i "s/^GDBNAME =/GDBNAME = \"${dbName}\"/" /home/oracle/dbca.rsp
sed -i "s/^SID =/SID = \"${dbName}\"/" /home/oracle/dbca.rsp
sed -i "s/^NODELIST=/NODELIST=${env}-${localNode}/" /home/oracle/dbca.rsp
chown oracle:oinstall /home/oracle/dbca.rsp
su - oracle -c 'dbca -silent -createdatabase -redoLogFileSize 100 -responseFile "/home/oracle/dbca.rsp"'

# DB实例创建完成，检查集群服务的实例情况
su - grid -c "srvctl status database -d ${dbName}"
su - grid -c "srvctl config database -d ${dbName} -a"
#su - grid -c 'srvctl config nodeapps -a -g -s -l'
su - oracle -c 'sqlplus / as sysdba'<<EOF
col host_name format a20
set linesize 200
select INSTANCE_NAME,HOST_NAME,VERSION,STARTUP_TIME,STATUS,
  ACTIVE_STATE,INSTANCE_ROLE,DATABASE_STATUS
  from gv\$INSTANCE;
quit;
EOF
su - oracle -c 'lsnrctl services'
su - oracle -c 'emctl status dbconsole'

echo "**************DB实例创建结束****************"

echo "***********监控用户环境设置开始*************"

su - grid -c "sqlplus / as sysdba"<<EOF
show parameter remote;
ALTER SYSTEM SET remote_listener="${env}-${localNode}:1521";
ALTER SYSTEM REGISTER;
show parameter remote;
quit;
EOF

su - oracle -c 'sqlplus sys/password as sysdba'<<EOF
select file_name from dba_data_files;
select name from v\$tempfile;

CREATE TABLESPACE ts_spot
DATAFILE '+DATA' SIZE 2048M REUSE AUTOEXTEND
ON NEXT 50M MAXSIZE 10240M,
'+DATA' SIZE 2048M REUSE AUTOEXTEND
ON NEXT 50M MAXSIZE 10240M
EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

CREATE TEMPORARY TABLESPACE ts_spot_temp
TEMPFILE '+DATA' SIZE 1024M AUTOEXTEND ON
NEXT 32M MAXSIZE 8192M,
'+DATA' SIZE 1024M AUTOEXTEND ON
NEXT 32M MAXSIZE 8192M
EXTENT MANAGEMENT LOCAL;

select file_name from dba_data_files;
select name from v\$tempfile;

quit;
EOF

echo "***********监控用户环境设置结束*************"

echo "************主数据库初始化开始**************"
# 只有主数据库需要做以下初始化，dg、rman库都不需要

if [ ${localNode} == ${node1} ]; then

su - oracle -c "sqlplus / as sysdba"<<EOF

-- create tablespace
CREATE TABLESPACE ts_spot
DATAFILE '+DATA' SIZE 2048M REUSE AUTOEXTEND
ON NEXT 50M MAXSIZE 10240M,
EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;
CREATE TEMPORARY TABLESPACE ts_spot_temp
TEMPFILE '+DATA' SIZE 1024M AUTOEXTEND ON
NEXT 32M MAXSIZE 8192M
EXTENT MANAGEMENT LOCAL;

CREATE TABLESPACE ts_tvpay2
DATAFILE '+DATA' SIZE 10240M REUSE AUTOEXTEND
ON NEXT 2048M MAXSIZE 20480M,
'+DATA' SIZE 10240M REUSE AUTOEXTEND
ON NEXT 2048M MAXSIZE 20480M
EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

CREATE TABLESPACE ts_tvpay2_index
DATAFILE '+DATA' SIZE 10240M REUSE AUTOEXTEND
ON NEXT 2048M MAXSIZE 20480M,
'+DATA' SIZE 10240M REUSE AUTOEXTEND
ON NEXT 2048M MAXSIZE 20480M
EXTENT MANAGEMENT LOCAL SEGMENT SPACE MANAGEMENT AUTO;

CREATE TEMPORARY TABLESPACE ts_tvpay_temp
TEMPFILE '+DATA' SIZE 2048M AUTOEXTEND ON
NEXT 1024M MAXSIZE 8192M,
'+DATA' SIZE 2048M AUTOEXTEND ON  
NEXT 1024M MAXSIZE 8192M
EXTENT MANAGEMENT LOCAL;

-- set Flash Recover Area
alter system set db_recovery_file_dest_size=${DISKC}G  scope=both;
alter system set db_flashback_retention_target=10080 scope=both; 
alter system set sessions=3000 scope=spfile;
alter system set processes=2000 scope=spfile;

-- open archivelog and flashback
shutdown immediate;
startup mount;
alter database archivelog;
alter database flashback on;
shutdown immediate;
startup;

-- Create the user and grant privileges
create user TVPAY2
  identified by tvpay
  default tablespace TS_TVPAY2
  temporary tablespace TS_TVPAY_TEMP
  profile DEFAULT;
-- Grant/Revoke object privileges 
grant execute on DBMS_CRYPTO to TVPAY2;
grant select on V_\$INSTANCE to TVPAY2;
-- Grant/Revoke role privileges 
grant connect to TVPAY2;
grant resource to TVPAY2;
-- Grant/Revoke system privileges 
grant unlimited tablespace to TVPAY2;

quit;
EOF

fi

echo "************主数据库初始化结束**************"

### 第七部分：节点定制收尾工作

# 删除临时网卡子接口
ifdown ${netIf}:1
rm -f /etc/sysconfig/network-scripts/ifcfg-${netIf}:1
echo "------------------检查结果------------------"
ls /etc/sysconfig/network-scripts/ifcfg-${netIf}*

# 调整nrpe用户
sed -i 's/nrpe_user=nagios/nrpe_user=oracle/g' /usr/local/nagios/etc/nrpe.cfg
sed -i 's/nrpe_group=nagios/nrpe_group=oinstall/g' /usr/local/nagios/etc/nrpe.cfg
usermod -G oinstall nagios
echo "------------------检查结果------------------"
grep nrpe_user /usr/local/nagios/etc/nrpe.cfg
grep nrpe_group /usr/local/nagios/etc/nrpe.cfg
id nagios

# 脚本自毁
rm -rf /root/shscript/syscus
echo "------------------检查结果------------------"
ls /root/shscript/

# 重启系统
init 6
