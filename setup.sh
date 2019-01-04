#! /bin/bash
#set -x

whoami | grep -q '^root$' || exit 1

echo -n "Setup script started: "
date
# ./setup.sh 2>&1 | tee setup.log
# TODO: consider fault tolerance. should a single minor issue like a patch not being applied bring the script to a screeching halt?



SETUPPATH=/root/clydesetup
SETUPFAIL=0

# set cwd to /root/clydesetup, verify that that is where _we_ are
cd "$SETUPPATH"  # we don't seem to need this; TODO: derive abs path from $0 or something and use that instead of hard-coded clydesetup path
pwd | grep -q "^$SETUPPATH$" || exit 1

# make sure we have everything we need *before* starting the setup process
# this is important because if we don't the script may fail and leave the system in an inconsistent state, creating a need to reinstall a fresh system all over again
if [[ ! -e "$SETUPPATH/setup.private" || ! -e "$SETUPPATH/backupkey.private" || ! -e "$SETUPPATH/clydebackup.tar" || ! -e "$SETUPPATH/clydesrv.tar.gz" ]]
then
	echo "Need:"
	echo "  setup.private"
	echo "  backupkey.private"
	echo "  clydebackup.tar"
	echo "  clydesrv.tar.gz"
	echo "Missing. Ends."
	exit 1
fi

# init
chown -R root:root "$SETUPPATH"
export LANG=C.UTF-8
update-locale LANG=C.UTF-8
#export LC_ALL=C



setup_repo_permissions () {
	# usage: setup_repo_permissions /path/to/repo/etc/configfile R
	# Confirms that the specified file exists and sets its permissions.
	
	[ $# -ge 1 ] || return 9  # file path (required argument)
	PATH_REP="$1"
	[ -e "$PATH_REP" ] || return 3
	
	if [ $# -ge 2 ]  # permissions
	then
		if [ "$2" = "X" ]
		then
			chmod -v 755 "$PATH_REP"
		elif [ "$2" = "R" ]
		then
			chmod -v 644 "$PATH_REP"
		else
			chmod -v "$2" "$PATH_REP"
		fi
	fi
}



setup_copy () {
	# usage: setup_copy /etc/configfile R
	# Creates the config file at the specified location by copying from
	# the repository.
	
	[ $# -ge 1 ] || ( echo "setup_copy error 9: file path (required argument)" && exit 9 )
	PATH_SYS="$1"
	PATH_REP="$SETUPPATH$1"
	
	setup_repo_permissions "$PATH_REP" $2  # 2nd arg is optional
	[ $? -ne 0 ] && echo "setup_copy error 3: '$1' '$2'" && exit 3
	
	[ -e "$PATH_SYS" ] && mv -v "$PATH_SYS" "$PATH_REP.orig"
	echo "copying $PATH_SYS"
	mkdir -p `dirname $PATH_SYS`
	cp "$PATH_REP" "$PATH_SYS"
}



setup_patch () {
	# usage: setup_patch /etc/configfile
	# Creates the config file at the specified location by patching the
	# existing file at that location with a patch from the repository.
	
	# create patch:
	# diff -U2
	
	[ $# -ge 1 ] || ( echo "setup_copy error 9: file path (required argument)" && exit 9 )
	PATH_SYS="$1"
	PATH_REP="$SETUPPATH$1"
	[ -e "$PATH_REP.patch" ] && [ -e "$PATH_SYS" ] || ( echo "setup_copy error 3: '$1'" && exit 3 )
	
	patch -b -V simple -z .orig "$PATH_SYS" < "$PATH_REP.patch"
	[ -e "$PATH_SYS.orig" ] && mv -v "$PATH_SYS.orig" "$PATH_REP.orig"
}




### user prefs
## Clyde

setup_copy /etc/skel/.bashrc X

setup_patch /etc/bash.bashrc
setup_patch /root/.bashrc



### SSH
## Clyde

# prepare shared Git repo

adduser --disabled-password --uid 201 --gecos "Git shared access" git
mkdir -p /home/git/.ssh /srv/git
touch /home/git/.ssh/authorized_keys
chmod 700 /home/git/.ssh
chmod 644 /home/git/.ssh/authorized_keys
chown -R git:git /home/git/.ssh /srv/git
#sudo -u git ln -s /srv/git /home/git/srv


# setup user accounts

setup_copy /etc/sudoers.d/wheel 0440
addgroup --gid 500 wheel
addgroup --gid 501 skgb-web  # group skgb-web is probably no longer required

setup_super_user () {
	# usage: setup_super_user "loginname" "Real Name"
	# Adds the specified user to the system with full sudo privileges.
	
	echo "setup_super_user $1 '$2'"
	adduser --disabled-password --gecos "$2" "$1"
	adduser "$1" wheel  # sudoer
	adduser "$1" adm  # read log files
	adduser "$1" skgb-web
	mkdir -p "/home/$1/.ssh"
	touch "/home/$1/.ssh/authorized_keys"
	chmod 700 "/home/$1/.ssh"
	chmod 644 "/home/$1/.ssh/authorized_keys"
	chown -R "$1:$1" "/home/$1/.ssh"
}

setup_insecure_password () {
	# usage: PASSWORD=`setup_insecure_password`
	# Returns a fresh pseudo-random password. While this password is not
	# cryptographically secure, it might still be good enough for certain
	# low-security applications.
	
	perl -e '$l=$ARGV[0]||16; @c=(("A".."Z"),("a".."z"),(0..9)); $n=$#c+1; for(1..$l){$p.=$c[int(rand($n))];} print $p;' $1
}

setup_user_forward () {
	# usage: setup_user_forward "loginname" "mailbox@host.example"
	# Installs a .forward file in the user's home dir.
	
	echo "$2" > "/home/$1/.forward"
	chown "$1":"$1" "/home/$1/.forward"
	chmod 644 "/home/$1/.forward"
}

. "$SETUPPATH/setup.private"

setup_patch /etc/ssh/sshd_config



### hostname and login message

setup_copy /etc/motd R
setup_copy /etc/init.d/hostname_vps X
update-rc.d hostname_vps defaults 09
setup_copy /etc/profile.d/motd.sh X

# If dist-upgrading to sid is intended, right now would be an appropriate time to do so.



### install software
echo
echo "We will now install Debian software packages."
echo

apt-get upgrade

# make Neo4j available in apt sources
apt-get install gnupg wget  # these should be installed by default, making this a no-op
wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -  # Import Neo4j signing key
setup_copy /etc/apt/sources.list.d/neo4j.list R
apt-get update
# Neo4j 3.0 requires Java 8, which openjdk only offers for Debian 9 at this point => stick to Neo4j 2.3 for now
apt-get install neo4j=2.3.6
apt-mark hold neo4j

export DEBIAN_FRONTEND=noninteractive
apt-get -y install $(cat installed-software.log | awk '{print $1}') || exit
export DEBIAN_FRONTEND=

# see https://www.bsi.bund.de/DE/Themen/Cyber-Sicherheit/Aktivitaeten/CERT-Bund/CERT-Reports/HOWTOs/Offene-Portmapper-Dienste/Offene-Portmapper-Dienste_node.html
apt-get remove rpcbind

# install Let's Encrypt for SSL
# (unavailable in Debian 8 => backports)
setup_copy /etc/apt/sources.list.d/letsencrypt.list R
apt-get update
# apt-cache policy certbot
# apt-get install python-setuptools=20.10.1-1.1~bpo8+1 python-pkg-resources=20.10.1-1.1~bpo8+1
apt-get -y -t jessie-backports install certbot python-certbot-apache



### Set up databases

# passwords are sourced from the setup.private file

# MySQL
mysqladmin flush-privileges
mysql mysql --user=root <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');
SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('$MYSQL_ROOT_PASSWORD');
SET PASSWORD FOR 'root'@'::1' = PASSWORD('$MYSQL_ROOT_PASSWORD');
DELETE FROM user WHERE user = 'root' AND password = '';
FLUSH PRIVILEGES;
EOF
#CREATE USER 'root'@'clyde.skgb.de' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
#GRANT ALL PRIVILEGES ON *.* TO 'root'@'clyde.skgb.de';

setup_copy /root/.my.cnf 600
sed -e "/^password = .*/s//password = \"$MYSQL_ROOT_PASSWORD\"/" -i /root/.my.cnf

mysql <<EOF
CREATE USER 'backup'@'localhost' IDENTIFIED BY '$MYSQL_BACKUP_PASSWORD';
GRANT SELECT, SHOW DATABASES, LOCK TABLES, EVENT ON *.* TO 'backup'@'localhost';
CREATE USER 'skgb-intern'@'%' IDENTIFIED BY '$MYSQL_INTERN_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON postfix.* TO 'skgb-intern'@'%';
CREATE USER 'postfix'@'127.0.0.1' IDENTIFIED BY '$MYSQL_POSTFIX_PASSWORD';
GRANT SELECT ON postfix.* TO 'postfix'@'127.0.0.1';
CREATE USER 'skgb-web'@'localhost' IDENTIFIED BY '$MYSQL_WP_WWW_PASSWORD';
GRANT ALL PRIVILEGES ON \`skgb_web\`.* TO 'skgb-web'@'localhost';
CREATE USER 'db10959533-wpdev'@'localhost' IDENTIFIED BY '$MYSQL_WP_DEV_PASSWORD';
GRANT ALL PRIVILEGES ON \`db10959533-wordpressdev\`.* TO 'db10959533-wpdev'@'localhost';
EOF
# NB: mysql doesn't seem to be accessible over the network

# Neo4j
curl -iH "Content-Type: application/json" -X POST -d "{\"password\":\"$NEO4J_PASSWORD\"}" -u neo4j:neo4j http://localhost:7474/user/neo4j/password
setup_patch "/etc/neo4j/neo4j.properties"



### Configure MTA
setup_copy /etc/postfix/main.cf R
setup_copy /etc/postfix/skgb-virtual.cf R
sed -e "/^password = .*/s//password = $MYSQL_POSTFIX_PASSWORD/" -i /etc/postfix/skgb-virtual.cf
setup_copy /etc/aliases R
setup_copy /etc/postfix/virtual R
newaliases
postmap hash:/etc/postfix/virtual
postfix status && postfix reload || postfix start
setup_copy /etc/postfix/reload X



### Set up backups
mkdir -p /root/.gnupg
chmod 700 /root/.gnupg
mv -v backupkey.private /root/.gnupg/EF330646-sec.asc
setup_repo_permissions /root/.gnupg/EF330646-sec.asc 600
setup_copy /root/.gnupg/75EB52B0.asc 600
setup_copy /root/.gnupg/816EE403.asc 600
setup_copy /root/.gnupg/otrust.txt 600
gpg2 --import /root/.gnupg/*.asc
gpg2 --import-ownertrust < /root/.gnupg/otrust.txt
gpg2 --check-trustdb
setup_copy /root/backupexport.sh X
sed -e "/^MYSQL_BACKUP_PASSWORD=.*/s//MYSQL_BACKUP_PASSWORD='--password=$MYSQL_BACKUP_PASSWORD'/" -i /root/backupexport.sh
setup_copy /root/backupimport.sh X
setup_copy /root/backupoffsite.sh X
setup_copy /root/backuprotate.conf R
mkdir -p /root/backups
setup_copy /etc/cron.daily/backupoffsite X
setup_copy /etc/cron.hourly/backup X



### Get transient data from backup
# Significantly this includes reading an encrypted database dump.
# Requires an interactive shell for PGP passphrase input!
/root/backupimport.sh "$SETUPPATH/clydebackup.tar" -y || SETUPFAIL=1

# the backup import will overwrite the password, in which case logrotate may start to send daily email complaints to root
# (because of "error: 'Access denied for user 'debian-sys-maint'@'localhost' (using password: YES)'", which isn't given in the email though)
# solution: read new password from /etc/mysql/debian.cnf and set that as the new password for debian-sys-maint in mysql, overwriting the imported backup
echo -n "MySQL Debian maintenance password:" ; MYSQL_DEBIAN_PASSWORD=$( echo $(awk -F "=" '/password/ {print $2}' /etc/mysql/debian.cnf ) | sed -e 's/ .*$//' ) && (echo " setting to '$MYSQL_DEBIAN_PASSWORD'"; echo "SET PASSWORD FOR 'debian-sys-maint'@'localhost' = PASSWORD('$MYSQL_DEBIAN_PASSWORD');" | mysql ) || echo ' password unchanged (error!)' && SETUPFAIL=2
mysqladmin flush-privileges

# the backup import will overwrite the MTA's virtual alias table
/etc/postfix/reload



### SSL

echo "Preparing SSL (with self-signed certificate) ..."
setup_copy /etc/ssl/skgb/dummy-config R
openssl req -config /etc/ssl/skgb/dummy-config -x509 -newkey rsa -days 1 -nodes -out /etc/ssl/skgb/dummy-cert.pem
ln -s dummy-cert.pem /etc/ssl/skgb/fullchain.pem
ln -s dummy-key.pem /etc/ssl/skgb/privkey.pem



### Apache

APACHE_DIR=/etc/apache2

for user in `awk -F':' '/^skgb-web/{print $4}' /etc/group | sed -e 's/,/ /g'`
do
	addgroup "$user" www-data
done

mkdir -p /srv/Log/
chown root:adm /srv/Log
chmod 750 /srv/Log
ln -s /var/log/apache2/error.log /srv/Log/error
ln -s /var/log/apache2/error.log.1 /srv/Log/error.1
setup_copy "$APACHE_DIR/conf-available/logging.conf" R
setup_copy /etc/logrotate.d/apache2-srv R

setup_patch "$APACHE_DIR/conf-available/security.conf"
setup_patch "/etc/mime.types"

a2enconf logging
a2disconf charset
a2disconf localized-error-pages
a2disconf other-vhosts-access-log
a2disconf serve-cgi-bin

a2enmod actions
a2enmod auth_digest
a2enmod authz_groupfile
a2enmod cgi
a2enmod expires
a2enmod headers
a2enmod include
a2enmod rewrite
a2enmod proxy_http

# the following should be available by default, but let's make sure they're available anyway
a2enmod alias
a2enmod auth_basic
a2enmod authn_file
a2enmod autoindex
a2enmod env
a2enmod mime
a2enmod negotiation
a2enmod php5
a2enmod ssl

setup_copy "$APACHE_DIR/conf-available/ssl.conf" R
a2enconf ssl
setup_copy /etc/cron.daily/apachessl X
setup_copy /etc/php5/apache2/conf.d/skgb-intern.php.ini R

a2dissite 000-default
mv "$APACHE_DIR/sites-available/000-default.conf" "$APACHE_DIR/sites-available/000-default.conf.orig"  # HFS compatibility
setup_copy "$APACHE_DIR/sites-available/000-Default.conf" R
a2ensite 000-Default

setup_copy "$APACHE_DIR/sites-available/archiv.conf" R
a2ensite archiv
setup_copy "$APACHE_DIR/sites-available/intern.conf" R
a2ensite intern
setup_copy "$APACHE_DIR/sites-available/intern1.conf" R
a2ensite intern1
setup_copy "$APACHE_DIR/sites-available/servo.conf" R
a2ensite servo
setup_copy "$APACHE_DIR/sites-available/skgb.conf" R
a2ensite skgb
setup_copy "$APACHE_DIR/sites-available/www.conf" R
a2ensite www

echo "Installing /srv ..."
( cd /srv ; tar -xzf "$SETUPPATH/clydesrv.tar.gz" )

# TODO: make sure that the ownership is correct:
# Data needs OWNER www-data
chown -R www-data:www-data /srv/Data
chmod 700 /srv/Data
chmod 600 /srv/Data/*
# WP selfupdate should work with GROUP www-data, but seems to in fact need OWNER www-data
# everything else needs GROUP www-data
#chgrp -R www-data /srv/Default
# (historically, skgb-web is equivalent)

apachectl graceful-stop
apachectl configtest
apachectl start



### CA-signed SSL certificate

echo "Obtaining SSL certificate from Let's Encrypt..."
#letsencrypt certonly --test-cert --apache --non-interactive --agree-tos --email webmaster+le@skgb.de --domains intern.skgb.de,intern2.skgb.de,clyde.skgb.de

if certbot certonly --apache --non-interactive --agree-tos --email webmaster+le@skgb.de --domain skgb.de \
	--domain archiv.skgb.de \
	--domain clyde.skgb.de \
	--domain intern.skgb.de \
	--domain intern2.skgb.de \
	--domain servo.skgb.de \
	--domain www.skgb.de
then
	echo "Let's Encrypt was successful; switching out certificate links ..."
	rm -f /etc/ssl/skgb/fullchain.pem /etc/ssl/skgb/privkey.pem
	ln -vs /etc/letsencrypt/live/skgb.de/fullchain.pem /etc/ssl/skgb/fullchain.pem
	ln -vs /etc/letsencrypt/live/skgb.de/privkey.pem /etc/ssl/skgb/privkey.pem
	apachectl graceful
else
	echo "Error with Let's Encrypt."
	echo "*** Using self-signed certificate! ***"
	SETUPFAIL=3
fi

setup_copy /etc/cron.daily/letsencrypt-skgb X



# Install LOMS Service
# (Don't enable yet: We need to brew Perl first.)
setup_copy /etc/init.d/skgb-intern.sh X



### IPv6
setup_copy /etc/network/interfaces.d/ip6 R
# also requires activation in VCP and a cold reboot



### Bind
#setup_copy /etc/bind/named.conf.options R
#setup_copy /etc/bind/named.conf.local R
#setup_copy /etc/bind/skgb.de R
#/etc/init.d/bind9 reload
#setup_copy /etc/bind/reload X



# report errors now instead of at the script's end because Perl install overwrites the SETUPFAIL variable
# TODO: better error handling
if [ "$SETUPFAIL" -ne 0 ] ; then
	echo 1>&2
	echo "*** ERRORS HAVE OCCURRED ***" 1>&2
	echo "(error code: $SETUPFAIL)" 1>&2
	echo 1>&2
	# NB: absence of this message does not signify the absence of errors
fi



### Perl
# Building & installing Perl is ridiculously slow. It might be preferable to
# get postfix up and running ASAP, then perhaps Apache to be able to at least
# serve static pages, and only then start brewing Perl and stuff. Also, we must
# ensure that Apache behaves as it should during this state. Either 503s need
# to be served or the server shouldn't be running at all.
# 503s WILL be served if the reverse proxy detects Mojo isn't running. So the
# best strategy is prolly (1) MySQL, (2) Apache, (3) Postfix, (4) perl+neo4j;
# the goal being to get www up and running ASAP, then spend time on getting
# things moving over at intern while 503s are served.

# A reboot before brewing perl may be useful to be sure it picks up the new host name. -- TODO: I think I got this from some guide, but it may be BS. Try without reboot first!

echo -n "Beginning to brew Perl: "
date

export PERLBREW_ROOT=/opt/perlbrew
curl -kL http://install.perlbrew.pl | bash
echo "source $PERLBREW_ROOT/etc/bashrc" >> /root/.bashrc
source "$PERLBREW_ROOT/etc/bashrc"  # note sure if this is enough ... the docs require a new shell
perlbrew init
PERL_INSTALL_VERSION=$( perlbrew available | grep perl-5.24 | cut -b 3- )
perlbrew install "$PERL_INSTALL_VERSION" || SETUPFAIL=21
#perlbrew use $( perlbrew available | grep perl-5.24 | cut -b 3- )  # 'use' means this session only
perlbrew switch "$PERL_INSTALL_VERSION"

echo -n "Finished brewing Perl: "
date

cpan -u

# The brew tends to fail on the first try. As a last resort, --notest should help:
# perlbrew --notest install perl-stable
# perlbrew --force install perl-stable

# not all of these modules may actually be required - some might be in this list just because I need them on Cat or Pentland

# some XS modules require additional packages for linking
apt-get -y install libxml2-dev zlib1g-dev libxslt1-dev libssl-dev libmysqlclient-dev
cpan XML::LibXML XML::LibXSLT HTML::HTML5::Parser IO::Socket::SSL DBD::mysql || SETUPFAIL=22

# the pure Perl modules should be installed after the XS modules to make sure
# that dependencies can be properly satisfied
cpan Devel::StackTrace Text::Trim String::Random HTML::Entities DBI DBD::mysql || SETUPFAIL=23
cpan Mojolicious DateTime DateTime::Format::ISO8601 Time::Date Mojo::SMTP::Client Email::MessageID || SETUPFAIL=24
cpan String::Util List::MoreUtils Util::Any Digest::MD5 Mojolicious::Plugin::Authorization || SETUPFAIL=25
cpan Perl::Version SemVer Text::WordDiff || SETUPFAIL=26
cpan REST::Client Cpanel::JSON::XS JSON::MaybeXS Regexp::Common || SETUPFAIL=27

# Neo4j
cpan -fi LWP::Protocol::https REST::Neo4p || SETUPFAIL=28

# NOT currently used on Clyde: proj
#apt-get -y install libproj-dev
#cpan Geo::Proj4 Geo::Proj || SETUPFAIL=29



echo
echo "Perl install: All done!"
if [ "$SETUPFAIL" -gt 20 ] ; then
	echo "(errors seem to have occurred; code $SETUPFAIL)"
	# note that only the last error code will be reported here
	# TODO: better error handling
fi
echo



# Enable LOMS
update-rc.d skgb-intern.sh defaults
#/etc/init.d/skgb-intern.sh start
setup_copy /etc/cron.d/skgb-intern R

# shutdown -r now


echo -n "Setup script finished: "
date

echo

exit 0
