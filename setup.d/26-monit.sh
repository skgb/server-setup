#!bash


### Monit

setup_patch /etc/monit/monitrc
ln -s ../conf-available/rsyslog /etc/monit/conf-enabled/rsyslog

systemctl restart monit.service

