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
if [[ ! -e "$SETUPPATH/credentials.private" || ! -e "$SETUPPATH/backupkey.private" || ! -e "$SETUPPATH/clydebackup.tar" || ! -e "$SETUPPATH/clydesrv.tar" ]]
then
  echo "Need:"
  echo "  credentials.private"
  echo "  backupkey.private"
  echo "  clydebackup.tar"
  echo "  clydesrv.tar"
  echo "Missing. Ends."
  exit 1
fi

# init
chown -R root:root "$SETUPPATH"
export LANG=C.UTF-8
export LC_CTYPE=
update-locale LANG=C.UTF-8
apt-get install patch



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

. "$SETUPPATH/credentials.private"

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
apt-get -y install gnupg wget  # these should be installed by default, making this a no-op
wget -O - https://debian.neo4j.org/neotechnology.gpg.key | apt-key add -  # Import Neo4j signing key
setup_copy /etc/apt/sources.list.d/neo4j.list R
apt-get update
apt-get -y install neo4j
#apt-get install neo4j=2.3.6
#apt-mark hold neo4j
setup_copy /etc/security/limits.d/neo4j R
service neo4j stop
# see <http://github.com/neo4j-contrib/neo4j-apoc-procedures/releases>
(cd /var/lib/neo4j/plugins ; wget -nv http://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/3.5.0.1/apoc-3.5.0.1-all.jar)
setup_patch /etc/neo4j/neo4j.conf
service neo4j start
systemctl enable neo4j.service

export DEBIAN_FRONTEND=noninteractive
apt-get -y install $(cat "$SETUPPATH/installed-software.log" | awk '{print $1}') || exit

# see https://www.bsi.bund.de/DE/Themen/Cyber-Sicherheit/Aktivitaeten/CERT-Bund/CERT-Reports/HOWTOs/Offene-Portmapper-Dienste/Offene-Portmapper-Dienste_node.html
apt-get remove rpcbind  # probably no longer installed by default => no-op

# install Let's Encrypt for SSL
# (unavailable in Debian 8 => backports)
setup_copy /etc/apt/sources.list.d/letsencrypt.list R
apt-get update
# apt-cache policy certbot
# apt-get install python-setuptools=20.10.1-1.1~bpo8+1 python-pkg-resources=20.10.1-1.1~bpo8+1
apt-get -y -t stretch-backports install certbot python-certbot-apache
export DEBIAN_FRONTEND=
# wildcard certs require DNS validation
curl -LO "https://github.com/kegato/letsencrypt-inwx/releases/download/1.1.1/letsencrypt-inwx_1.1.1_amd64.deb"
dpkg -i letsencrypt-inwx_1.1.1_amd64.deb
rm -f letsencrypt-inwx_1.1.1_amd64.deb
setup_copy /etc/letsencrypt-inwx-cred 600
echo "$SKGB_INWX_PASSWORD" >> /etc/letsencrypt-inwx-cred
# possible alternative: <https://github.com/oGGy990/certbot-dns-inwx>

# Wordpress CLI <https://wp-cli.org/>
mkdir -p /opt/wp-cli
cd /opt/wp-cli
curl -LO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
ln -s /opt/wp-cli/wp-cli.phar /usr/local/bin/wp
mkdir -p /var/www/.wp-cli/cache
chown -R www-data:www-data /var/www/.wp-cli

# prep dirs
cd /srv
SRV_LIST_WP="www dev"
SRV_LIST_INTERN="intern legacy"
SRV_LIST_STATIC="archiv servo"
SRV_LIST_FULL="$SRV_LIST_WP $SRV_LIST_INTERN $SRV_LIST_STATIC"
mkdir $SRV_LIST_FULL
chown git:git git
chown www-data:www-data $SRV_LIST_WP
chown aj:www-data $SRV_LIST_INTERN
chown aj:skgb-web $SRV_LIST_STATIC
chmod 2755 $SRV_LIST_FULL
chmod 2775 $SRV_LIST_WP
cd "$SETUPPATH"



### Set up databases

# passwords are sourced from the credentials.private file

# MySQL
# local access is provided to root via socket connection
# for remote access (SSH only), a rootssh user is added
mysqladmin flush-privileges
#mysql mysql --user=root <<EOF
#SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_ROOT_PASSWORD');
##SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('$MYSQL_ROOT_PASSWORD');
##SET PASSWORD FOR 'root'@'::1' = PASSWORD('$MYSQL_ROOT_PASSWORD');
#DELETE FROM user WHERE user = 'root' AND password = '';
mysql mysql --user=root <<EOF
CREATE USER 'rootssh'@'127.0.0.1' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO 'rootssh'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF
#CREATE USER 'root'@'solent.skgb.de' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
#GRANT ALL PRIVILEGES ON *.* TO 'root'@'solent.skgb.de';

#setup_copy /root/.my.cnf 600
#sed -e "/^password = .*/s//password = \"$MYSQL_ROOT_PASSWORD\"/" -i /root/.my.cnf

mysql <<EOF
CREATE USER 'backup'@'localhost' IDENTIFIED BY '$MYSQL_BACKUP_PASSWORD';
GRANT SELECT, SHOW DATABASES, LOCK TABLES ON *.* TO 'backup'@'localhost';
CREATE USER 'skgb-intern'@'%' IDENTIFIED BY '$MYSQL_INTERN_PASSWORD';
GRANT SELECT, INSERT, UPDATE, DELETE ON postfix.* TO 'skgb-intern'@'%';
CREATE USER 'postfix'@'127.0.0.1' IDENTIFIED BY '$MYSQL_POSTFIX_PASSWORD';
GRANT SELECT ON postfix.* TO 'postfix'@'127.0.0.1';
CREATE USER 'skgb-web'@'localhost' IDENTIFIED BY '$MYSQL_WP_WWW_PASSWORD';
GRANT ALL PRIVILEGES ON \`skgb_web\`.* TO 'skgb-web'@'localhost';
CREATE USER 'skgb-dev'@'localhost' IDENTIFIED BY '$MYSQL_WP_DEV_PASSWORD';
GRANT ALL PRIVILEGES ON \`skgb_dev\`.* TO 'skgb-dev'@'localhost';
EOF

# Neo4j
curl -iH "Content-Type: application/json" -X POST -d "{\"password\":\"$NEO4J_PASSWORD\"}" -u neo4j:neo4j http://localhost:7474/user/neo4j/password
#setup_patch "/etc/neo4j/neo4j.properties"



### Configure MTA
setup_copy /etc/postfix/main.cf R
setup_copy /etc/postfix/skgb-virtual.cf R
sed -e "/^password = .*/s//password = $MYSQL_POSTFIX_PASSWORD/" -i /etc/postfix/skgb-virtual.cf
setup_copy /etc/aliases R
setup_copy /etc/postfix/virtual R
newaliases
postmap hash:/etc/postfix/virtual
setup_copy /etc/postfix/reload X

# Apparently systemd doesn't work well with postfix in Debian 9; see:
# https://serverfault.com/q/877626
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=877992
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=882141
# Let's just use monit to start postfix, avoiding all these pitfalls.
# Unfortunately, the default monit control file for postfix is also broken ... so let's fix it.
setup_patch /etc/monit/conf-available/postfix
service postfix stop
systemctl disable postfix.service
systemctl disable postfix@-.service
postfix start



### Set up backups
mkdir -p /root/.gnupg
chmod 700 /root/.gnupg
mv -v backupkey.private /root/.gnupg/260EC33C-sec.asc
setup_repo_permissions /root/.gnupg/260EC33C-sec.asc 600
setup_copy /root/.gnupg/75EB52B0.asc 600
setup_copy /root/.gnupg/816EE403.asc 600
setup_copy /root/.gnupg/otrust.txt 600
gpg2 --batch --import /root/.gnupg/*.asc
# note: in case of error "error sending to agent":
#gpgconf --kill gpg-agent ; gpgconf --launch gpg-agent
gpg2 --import-ownertrust < /root/.gnupg/otrust.txt
gpg2 --check-trustdb
setup_copy /root/backupcredentials R
sed -e "/^MYSQL_BACKUP_PASSWORD=.*/s//MYSQL_BACKUP_PASSWORD='--password=$MYSQL_BACKUP_PASSWORD'/" -i /root/backupcredentials
sed -e "/^NEO4J_BACKUP_PASSWORD=.*/s//NEO4J_BACKUP_PASSWORD='$NEO4J_PASSWORD'/" -i /root/backupcredentials
setup_copy /root/backupexport.sh X
setup_copy /root/backupimport.sh X
setup_copy /root/backupoffsite.sh X
setup_copy /root/backuprotate.conf R
mkdir -p /root/backups
setup_copy /etc/cron.daily/backupoffsite X
setup_copy /etc/cron.hourly/backup X



### Get transient data from backup
# Significantly this includes reading an encrypted database dump.
# Requires an interactive shell for PGP passphrase input!
export NEO4J_PASSWORD="$NEO4J_PASSWORD"
/root/backupimport.sh "$SETUPPATH/clydebackup.tar" -y || SETUPFAIL=1

# The backup import has copied the skgb_web database content over to the
# skgb_dev database to provide a current base point for further development.
# We need to make some fixes to complete the transfer.
apply_database_fix ()
{
	DB="$1"
	DBUSER="$2"
	DBPASS="$3"
	HOST="$4"
	NAME="$5"
	
	echo
	echo "USE ${DB}"
	( mysql --user="$DBUSER" --password="$DBPASS" --host=localhost --database="$DB" | expand -t 15 ) <<QUIT

# apply the important fixes
UPDATE skgb_options SET option_value = '${HOST}' WHERE option_name = 'siteurl';
UPDATE skgb_options SET option_value = '${HOST}' WHERE option_name = 'home';

# set the site's display name
# (to make the two installations easier distiguishable from each other)
UPDATE skgb_options SET option_value = '${NAME}' WHERE option_name = 'blogname';

# some features depend upon other settings (that remain constant)
UPDATE skgb_options SET option_value = 'uploads' WHERE option_name = 'upload_path';
UPDATE skgb_options SET option_value = '' WHERE option_name = 'upload_url_path';
UPDATE skgb_options SET option_value = '1' WHERE option_name = 'uploads_use_yearmonth_folders';

# we're done changing the database, so let's print a confirmation table
SELECT option_name, option_value FROM skgb_options WHERE option_name IN ('siteurl', 'home', 'blogname', 'upload_path') ORDER BY option_value;

QUIT
}
#                  DB       DBUSER   DBPASS                   HOST                NAME
apply_database_fix skgb_dev skgb-dev "$MYSQL_WP_DEV_PASSWORD" http://dev.skgb.de  "SKGB-Web Dev"

mysqladmin flush-privileges

# the backup import will overwrite the MTA's virtual alias table
/etc/postfix/reload



### SSL

echo "Preparing SSL (with self-signed certificate) ..."
setup_copy /etc/ssl/skgb/dummy-config R
openssl req -config /etc/ssl/skgb/dummy-config -x509 -newkey rsa -days 1 -nodes -out /etc/ssl/skgb/dummy-cert.pem
ln -s dummy-cert.pem /etc/ssl/skgb/fullchain.pem
ln -s dummy-key.pem /etc/ssl/skgb/privkey.pem

# Actually, the self-signed certificate is no longer really necessary.
# We now restore our existing CA-signed certificate from the backup, so
# we should be just about all set at this point.

if [ -f /etc/letsencrypt/live/skgb.de/fullchain.pem ] ; then
  echo "Let's Encrypt is available; switching out certificate links ..."
  rm -f /etc/ssl/skgb/fullchain.pem /etc/ssl/skgb/privkey.pem
  ln -vs /etc/letsencrypt/live/skgb.de/fullchain.pem /etc/ssl/skgb/fullchain.pem
  ln -vs /etc/letsencrypt/live/skgb.de/privkey.pem /etc/ssl/skgb/privkey.pem
#  apachectl graceful
else
  echo "Error with Let's Encrypt."
  echo "*** Using self-signed certificate! ***"
  SETUPFAIL=3
fi



### Apache
echo
echo "We will now install /srv files and configure Apache."
echo

apachectl graceful-stop
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
a2enmod php7.0
a2enmod ssl

setup_copy "$APACHE_DIR/conf-available/ssl.conf" R
a2enconf ssl
setup_copy /etc/cron.daily/apachessl X
setup_copy "$APACHE_DIR/sites-available/ssl-wildcard.include" R
setup_copy /etc/php/7.0/apache2/conf.d/skgb-intern.php.ini R

setup_copy /srv/Default/index.ascii.shtml R
a2dissite 000-default
mv "$APACHE_DIR/sites-available/000-default.conf" "$APACHE_DIR/sites-available/000-default.conf.orig"  # HFS compatibility
setup_copy "$APACHE_DIR/sites-available/000-Default.conf" R
setup_copy "$APACHE_DIR/sites-available/000-Default.include" R
a2ensite 000-Default

setup_wordpress () {
  sudo -u www-data -- wp "--path=$1" core download --locale=de_DE
  WP_CONFIG="wp-config_${1}.php"
  tar -xvf "$BACKUPSRVPATH" "$1/$WP_CONFIG"
  ln -s "$WP_CONFIG" "$1/wp-config.php"
  WP_HTACCESS="htaccess_${1}.conf"
  setup_copy "/srv/$1/$WP_HTACCESS" R
  #tar -xf "$BACKUPSRVPATH" "$1/$WP_HTACCESS"
  ln -s "$WP_HTACCESS" "$1/.htaccess"
  
  # these git commands have some filesystem permission issue when run as user aj...
  git -C "$1/wp-content/plugins" clone https://github.com/skgb/wordpress-plugin.git skgb-web
  sudo -u www-data -- wp "--path=$1" plugin install https://github.com/johannessen/bhcalendarchives/archive/master.zip --activate
  sudo -u www-data -- wp "--path=$1" plugin install https://littoral.michelf.ca/code/php-markdown/php-markdown-extra-1.2.8.zip --activate
  sudo -u www-data -- wp "--path=$1" plugin install parsedown-wp
  sudo -u www-data -- wp "--path=$1" plugin install classic-editor --activate
  sudo -u www-data -- wp "--path=$1" plugin install remove-generator-tag-for-wordpress
  sudo -u www-data -- wp "--path=$1" plugin install pjw-page-excerpt
  sudo -u www-data -- wp "--path=$1" plugin install wp-db-backup
  sudo -u www-data -- wp "--path=$1" plugin uninstall akismet
  git -C "$1/wp-content/themes" clone https://github.com/skgb/wordpress-theme-4.git skgb4
  git -C "$1/wp-content/themes" clone https://github.com/skgb/wordpress-theme-5.git skgb5
  sudo -u www-data -- wp "--path=$1" theme install twentyten
  sudo -u www-data -- wp "--path=$1" theme activate skgb5
}

BACKUPSRVPATH=/srv/clydesrv.tar
ln -s "$SETUPPATH/clydesrv.tar" "$BACKUPSRVPATH"
cd /srv

echo "Installing Wordpress into /srv/www ..."
tar -xf "$BACKUPSRVPATH" www/XML www/uploads
chown -R www-data:www-data /srv/www/uploads
setup_wordpress www

echo "Installing Wordpress into /srv/dev ..."
echo
echo "(There might be lots of warnings below; these are generally harmless.)"
echo
cp -R www/XML dev/XML
cp -R www/uploads dev/uploads
setup_wordpress dev
setup_copy /srv/dev/robots.txt R
echo
echo "(There might be lots of warnings above; these are generally harmless.)"
echo

chmod -R g+w $SRV_LIST_WP
rm -f /var/www/.wp-cli/cache/core/wordpress-*.tar.gz /var/www/.wp-cli/cache/plugin/*.zip

echo "Installing /srv/archiv and /srv/servo ..."
#sudo -u aj -- git clone https://github.com/skgb/web-static.git archiv
tar -xf "$BACKUPSRVPATH" archiv servo

echo "Installing git repository into /srv/git ..."
tar -xf "$BACKUPSRVPATH" git

# TODO: make sure that the ownership is correct:
# Data needs OWNER www-data
chown -R www-data:www-data /srv/Data
chmod 700 /srv/Data
chmod 600 /srv/Data/*
# WP selfupdate should work with GROUP www-data, but seems to in fact need OWNER www-data
# everything else needs GROUP www-data
#chgrp -R www-data /srv/Default
# (historically, skgb-web is equivalent)

setup_copy "$APACHE_DIR/sites-available/archiv.conf" R
a2ensite archiv
setup_copy "$APACHE_DIR/sites-available/servo.conf" R
setup_copy "$APACHE_DIR/sites-available/servo.include" R
a2ensite servo
setup_copy "$APACHE_DIR/sites-available/skgb.conf" R
a2ensite skgb
setup_copy "$APACHE_DIR/sites-available/www.conf" R
setup_copy "$APACHE_DIR/sites-available/www.include" R
setup_copy "$APACHE_DIR/sites-available/wwwdev.include" R
a2ensite www

apachectl configtest
apachectl start



# Install SKGB-intern

setup_copy /etc/init.d/skgb-intern.sh X

echo "Installing SKGB-intern into /srv/intern and /srv/legacy ..."
sudo -u aj -- git clone https://github.com/skgb/intern.git
tar -xf "$BACKUPSRVPATH" intern/skgb-intern.production.conf
tar -xf "$BACKUPSRVPATH" intern/public/Merkblatt\ Datenschutz.pdf
tar -xf "$BACKUPSRVPATH" intern/public/regeln/src-copy
tar -xf "$BACKUPSRVPATH" intern/public/lib
# see https://github.com/oetiker/mojolicious-plugin-reverseproxy/issues/5
tar -xvf "$BACKUPSRVPATH" intern/lib/Mojolicious/Plugin/ReverseProxy.pm

tar -xf "$BACKUPSRVPATH" Lib
tar -xf "$BACKUPSRVPATH" legacy
rm "$BACKUPSRVPATH"

setup_copy "$APACHE_DIR/sites-available/intern.conf" R
a2ensite intern
setup_copy "$APACHE_DIR/sites-available/intern1.conf" R
a2ensite intern1

apachectl configtest
apachectl graceful



### IPv6
setup_copy /etc/network/interfaces.d/ip6 R
# also requires activation in SCP and a cold reboot



### Bind
#setup_copy /etc/bind/named.conf.options R
#setup_copy /etc/bind/named.conf.local R
#setup_copy /etc/bind/skgb.de R
#/etc/init.d/bind9 reload
#setup_copy /etc/bind/reload X



### CommonMark

#apt-get install cmark libcmark-dev
# The CommonMark libcmark API isn't quite finalised and thus not
# available through dpkg as of this time (ETA Debian 10). We have to
# build it ourselves for now.
DEBIAN_FRONTEND=noninteractive apt-get -y install build-essential cmake
mkdir -p /opt/cmark
cd /opt/cmark
curl -LO https://github.com/commonmark/cmark/archive/0.28.3.tar.gz
tar -xzf 0.28.3.tar.gz
rm -f 0.28.3.tar.gz
cd cmark-0.28.3
make
#make test
#echo -n "*test*\n" | cmark
make install



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
curl -kL https://install.perlbrew.pl | bash
echo "source $PERLBREW_ROOT/etc/bashrc" >> /root/.bashrc
source "$PERLBREW_ROOT/etc/bashrc"  # note sure if this is enough ... the docs require a new shell
perlbrew init
#PERL_INSTALL_VERSION=$( perlbrew available | grep perl-5.28 | cut -b 3- )
PERL_INSTALL_VERSION=perl-5.28.1
# On dual core CPUs (like Solent), 2 jobs save a *lot* of time, while even more jobs save very little.
BREW_JOBS=3
perlbrew install -j "$BREW_JOBS" "$PERL_INSTALL_VERSION" || SETUPFAIL=21
#perlbrew use $( perlbrew available | grep perl-5.24 | cut -b 3- )  # 'use' means this session only
perlbrew switch "$PERL_INSTALL_VERSION"

echo -n "Finished brewing Perl: "
date

export TEST_JOBS="$BREW_JOBS"
export TESTING="--notest"
curl -L https://cpanmin.us | perl - App::cpanminus

cpanm $TESTING App::cpanoutdated
echo "Updating dual life modules:"
cpan-outdated --verbose | sed -e 's/ *[^ ]*$//'
cpan-outdated | cpanm $TESTING

# The brew tends to fail on the first try. As a last resort, --notest should help:
# perlbrew --notest install perl-stable
# perlbrew --force install perl-stable

# Actually, there is an argument to be made for always installing with --notest:
# <http://www.modernperlbooks.com/mt/2012/01/speed-up-perlbrew-with-test-parallelism.html#comment-1158>

# not all of these modules may actually be required - some might be in this list just because I need them on Cat or Pentland

# some XS modules require additional packages for linking
export DEBIAN_FRONTEND=noninteractive
apt-get -y install libxml2-dev zlib1g-dev libxslt1-dev libssl-dev libmariadbclient-dev
export DEBIAN_FRONTEND=
cpanm $TESTING XML::LibXML XML::LibXSLT HTML::HTML5::Parser IO::Socket::SSL DBD::mysql || SETUPFAIL=22
cpanm $TESTING CommonMark || SETUPFAIL=22

# the pure Perl modules should be installed after the linked XS modules to make sure
# that dependencies can be properly satisfied
cpanm $TESTING Module::Metadata Module::Install Devel::StackTrace Test::More Test::Exception Test::Warnings Text::Trim String::Random HTML::Entities || SETUPFAIL=23
cpanm $TESTING Mojolicious DateTime DateTime::Format::ISO8601 Time::Date Mojo::SMTP::Client Email::MessageID || SETUPFAIL=24
cpanm $TESTING String::Util List::MoreUtils Util::Any Digest::MD5 Mojolicious::Plugin::Authorization || SETUPFAIL=25
cpanm $TESTING Perl::Version SemVer Text::WordDiff || SETUPFAIL=26
cpanm $TESTING LWP::UserAgent REST::Client Cpanel::JSON::XS Try::Tiny URI || SETUPFAIL=27
cpanm $TESTING JSON::MaybeXS Regexp::Common || SETUPFAIL=27

# Neo4j
cpanm -n LWP::Protocol::https REST::Neo4p || SETUPFAIL=28
cpanm Neo4j::Driver || SETUPFAIL=28

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



### Monit
setup_patch /etc/monit/monitrc
setup_copy /etc/monit/conf.d/monit-http 0600
setup_copy /etc/monit/conf-available/neo4j 0600
setup_copy /etc/monit/conf-available/skgb-intern 0600
ln -s ../conf-available/apache2 /etc/monit/conf-enabled/apache2
ln -s ../conf-available/cron /etc/monit/conf-enabled/cron
ln -s ../conf-available/mysql /etc/monit/conf-enabled/mysql
ln -s ../conf-available/neo4j /etc/monit/conf-enabled/neo4j
ln -s ../conf-available/postfix /etc/monit/conf-enabled/postfix
ln -s ../conf-available/rsyslog /etc/monit/conf-enabled/rsyslog
ln -s ../conf-available/skgb-intern /etc/monit/conf-enabled/skgb-intern
systemctl restart monit.service

# Enable LOMS
#update-rc.d skgb-intern.sh defaults
setup_copy /etc/cron.d/skgb-intern R

# shutdown -r now


echo -n "Setup script finished: "
date

echo

exit 0
