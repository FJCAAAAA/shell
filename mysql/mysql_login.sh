#!/bin/sh
# mysql本地登陆脚本
source /etc/profile
Pass='UW1qZEVYMjMxNAo='

function decrypt_passwd
{
tmp_pass=$1
dec_pass=`echo $tmp_pass|base64 -d`
}

decrypt_passwd $Pass

mysql -uroot -p$dec_pass  
