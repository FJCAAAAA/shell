#!/bin/bash
#安装依赖
yum install gcc gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel gd-devel -y 
useradd nginx -s /sbin/nologin -M
mkdir /var/log/nginx
chown nginx:nginx /var/log/nginx/

#编译安装nginx
tar zxvf nginx-1.16.0.tar.gz
cd nginx-1.16.0
./configure --prefix=/etc/nginx \
--user=nginx \
--group=nginx \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib64/nginx/modules \
--with-pcre \
--with-http_ssl_module \
--with-http_v2_module \
--with-http_realip_module \
--with-http_addition_module \
--with-http_sub_module \
--with-http_dav_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gunzip_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_auth_request_module \
--with-http_image_filter_module \
--with-http_slice_module \
--with-mail \
--with-threads \
--with-file-aio \
--with-stream \
--with-mail_ssl_module \
--with-stream_ssl_module \

make  && make install


echo '[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target
 
[Service]
Type=forking
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx -c /etc/nginx/conf/nginx.conf
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop
PrivateTmp=true
 
[Install]
WantedBy=multi-user.target
' >> /usr/lib/systemd/system/nginx.service

systemctl enable nginx
