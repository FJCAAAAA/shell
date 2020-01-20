#!/bin/bash
#innobackupex恢复脚本
#on xtrabackup 2.4.15
#15810747029@163.com

INNOBACKUPEX_PATH=innobackupex  #INNOBACKUPEX的命令
INNOBACKUPEXFULL=/usr/bin/${INNOBACKUPEX_PATH}  #INNOBACKUPEX的命令路径
BACKUP_DIR=/backup # 备份的主目录
FULLBACKUP_DIR=${BACKUP_DIR}/full # 全库备份的目录
INCRBACKUP_DIR=${BACKUP_DIR}/incre # 增量备份的目录
IP_SQL1=10.254.0.201

#第一部分：ssh到SQL1上拉取备份文件
LAST_DATE=`date -d '1 days ago' +%Y-%m-%d `
ssh root@${IP_SQL1} "cd ${FULLBACKUP_DIR} && tar czf ${LAST_DATE}.tgz ${LAST_DATE}_*"
ssh root@${IP_SQL1} "cd ${INCRBACKUP_DIR} && tar czf ${LAST_DATE}.tgz ${LAST_DATE}_*"
scp root@${IP_SQL1}:${FULLBACKUP_DIR}/${LAST_DATE}.tgz ${FULLBACKUP_DIR}
scp root@${IP_SQL1}:${INCRBACKUP_DIR}/${LAST_DATE}.tgz ${INCRBACKUP_DIR}
ssh root@${IP_SQL1} "rm -f ${FULLBACKUP_DIR}/${LAST_DATE}.tgz"
ssh root@${IP_SQL1} "rm -f ${INCRBACKUP_DIR}/${LAST_DATE}.tgz"
tar zxf ${FULLBACKUP_DIR}/${LAST_DATE}.tgz -C ${FULLBACKUP_DIR} && rm -f ${FULLBACKUP_DIR}/${LAST_DATE}.tgz
tar zxf ${INCRBACKUP_DIR}/${LAST_DATE}.tgz -C ${INCRBACKUP_DIR} && rm -f ${INCRBACKUP_DIR}/${LAST_DATE}.tgz

#第二部分：恢复
${INNOBACKUPEXFULL} --apply-log  --redo-only ${FULLBACKUP_DIR}/${LAST_DATE}_*
${INNOBACKUPEXFULL} --apply-log ${FULLBACKUP_DIR}/${LAST_DATE}_*
systemctl stop mysqld
rm -rf /var/lib/mysql_bak/
mv /var/lib/mysql /var/lib/mysql_bak
mkdir /var/lib/mysql
${INNOBACKUPEXFULL} --copy-back ${FULLBACKUP_DIR}/${LAST_DATE}_*

if [[ $? == 0 ]];then
  echo "INNOBACKUPEX命令执行成功！"
else
  echo "INNOBACKUPEX命令执行失败！"
  exit 1
fi

chown -R mysql:mysql /var/lib/mysql
systemctl start mysqld
if [[ $? == 0 ]];then
  echo "mysql 启动成功！"
else
  echo "mysql 启动失败！"
  exit 1
fi



