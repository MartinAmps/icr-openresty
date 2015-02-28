#!/bin/bash

ICR_VERSION=0.1
NPS_VERSION=1.9.32.3
OR_VERSION=1.7.7.2
INSTALL=/tmp/openresty/$OR_VERSION
DEBUG=""

echo "Checking/Installing dependencies..."

apt-get update

apt-get -y install build-essential make unzip zip \
	git-core libssl-dev ruby ruby-dev \
	libpcre3 libpcre3-dev libgeoip-dev gem \
	zlib1g-dev

echo "Downloading OpenResty..."
if [ ! -f ngx_openresty-${OR_VERSION}.tar.gz ]; then
	wget http://openresty.org/download/ngx_openresty-${OR_VERSION}.tar.gz
fi

echo "Unarchiving..."

tar zxf ngx_openresty-${OR_VERSION}.tar.gz
cd ngx_openresty-${OR_VERSION}

echo "Downloading PageSpeed..."
if [ ! -f release-${NPS_VERSION}-beta.zip ]; then
	wget https://github.com/pagespeed/ngx_pagespeed/archive/release-${NPS_VERSION}-beta.zip
fi

echo "Unarchiving..."

unzip release-${NPS_VERSION}-beta.zip
cd ngx_pagespeed-release-${NPS_VERSION}-beta/
wget https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar -xzvf ${NPS_VERSION}.tar.gz

cd ..

echo "Configuring..."

./configure --prefix=/etc \
	--with-cc-opt='-g -O2 -fstack-protector-strong -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2' `#hardening RE: https://wiki.debian.org/Hardening` \
	--with-ld-opt=-Wl,-z,relro `#hardening RE: https://wiki.debian.org/Hardening` \
	--with-luajit \
	--with-pcre-jit \
	--with-ipv6 \
	--with-http_ssl_module \
	--with-http_auth_request_module \
	--with-http_addition_module \
	--with-http_sub_module \
	--with-http_realip_module \
	--with-http_gzip_static_module \
	--with-http_spdy_module \
	--with-http_stub_status_module \
	--with-http_secure_link_module \
	--with-http_geoip_module \
	--add-module=ngx_pagespeed-release-${NPS_VERSION}-beta \
	--sbin-path=/usr/sbin/nginx
	--conf-path=/etc/nginx/nginx.conf \
	--lock-path=/var/lock/nginx.lock \
	--pid-path=/run/nginx.pid \
	--http-client-body-temp-path=/var/lib/nginx/body \
	--http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
	--http-proxy-temp-path=/var/lib/nginx/proxy \
	--http-scgi-temp-path=/var/lib/nginx/scgi \
	--http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
	-j4

echo "Compiling..."
make

echo "Installing to ${INSTALL}"

make install DESTDIR=$INSTALL
mkdir -p $INSTALL/var/lib/nginx

cd ~

echo "Building deb..."

gem install fpm

fpm -s dir \
	-t deb \
	-n icr_webstack \
	-m "m@rtin.so" \
	-v ${ICR_VERSION} \
	-C $INSTALL \
	--url "https://git.icracked.com/martin/icr-webstack" \
	--description "iCracked webstack build ${ICR_VERSION} ${DEBUG}" \
	-d libgeoip1 \
	-d libpcre3 \
	--conflicts nginx-common \
	--conflicts nginx-extras \
	--conflicts nginx-full \
	--conflicts nginx-light \
	etc run var usr
