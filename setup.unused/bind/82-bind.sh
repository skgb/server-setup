#!bash


### Bind

setup_copy /etc/bind/named.conf.options R
setup_copy /etc/bind/named.conf.local R
setup_copy /etc/bind/skgb.de R
/etc/init.d/bind9 reload
setup_copy /etc/bind/reload X

