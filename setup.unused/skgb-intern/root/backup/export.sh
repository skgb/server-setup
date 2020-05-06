#! /bin/bash
#set -e
#set -x

# Create the backup tarball and store it locally.
# Inverse script: backup/import.sh


BACKUPDIR=/root/backup/files
BACKUPFILE=backup.tar
BACKUPSRVFILE=srv.tar

. /root/backup/credentials


mkdir -p "$BACKUPDIR"
cd "$BACKUPDIR"
date >> backuptimestamp
rm -f "$BACKUPFILE" databases.tar "$BACKUPSRVFILE"
tar -cf "$BACKUPFILE" backuptimestamp

# installed-software log
# we don't need this in a regular backup import, but no harm including it anyway
#dpkg --get-selections > installed-software.log
#tar -rf "$BACKUPFILE" installed-software.log
#rm -f installed-software.log
dpkg-query -l | sed -e '1,5d' -e 's/^... //g' -e 's/ \+/ /g' -e 's/^\([^ ]* [^ ]*\) .*/\1/' > installed-versions.log
bzip2 -c installed-versions.log > installed-versions.log.bz2
tar -rf "$BACKUPFILE" installed-versions.log.bz2
rm -f installed-versions.log installed-versions.log.bz2

# Perl installed module versions list
# (to help track incompatibilities after updates)
#perldoc -oText perllocal 2>&1 | grep '"Module"\|VERSION\|install \|"perllocal"' > installed-perl.log
# if which perlbrew > /dev/null && perldoc -V &> /dev/null
# then
#   export PERLBREW_ROOT=/opt/perlbrew
#   export PERLBREW_HOME=/root/.perlbrew
#   source ${PERLBREW_ROOT}/etc/bashrc
#   perlbrew use > installed-perl.log
#   /usr/bin/env perldoc -t perllocal > perllocal.log
#   for M in `grep '"Module"' perllocal.log | sed -e 's/^.*" //'`
#   do
#     V=`awk "/$M/{y=1;next}y" < perllocal.log | grep VERSION | head -n 1`
#     echo "$M $V"
#   done | sort -b >> installed-perl.log
#   bzip2 -c installed-perl.log > installed-perl.log.bz2
#   tar -rf "$BACKUPFILE" installed-perl.log.bz2
#   rm -f installed-perl.log installed-perl.log.bz2 perllocal.log
# fi

# file catalogue
# we don't usually need this either, but it may come in very handy in case of catastrophic failure
(find / | grep -v '^/boot/\|^/dev/\|^/sys/\|^/proc/\|^/root/\.cpanm\?/\|^/opt/perlbrew/build/') &> cata.log
bzip2 -c cata.log > cata.log.bz2
tar -rf "$BACKUPFILE" cata.log.bz2
rm -f cata.log cata.log.bz2


# MySQL
mysqldump --user=backup $MYSQL_BACKUP_PASSWORD postfix | bzip2 > mysql_postfix.sql.bz2
mysqldump --user=backup $MYSQL_BACKUP_PASSWORD skgb_web | bzip2 > mysql_skgb_web.sql.bz2
tar -cf databases.tar mysql_postfix.sql.bz2 mysql_skgb_web.sql.bz2
rm -f mysql_postfix.sql.bz2 mysql_skgb_web.sql.bz2

# # "Data" red-legacy db
# cd /srv
# tar -rf "$BACKUPDIR/databases.tar" Data
# cd "$BACKUPDIR"

# # Neo4j
# if which neo4j-shell > /dev/null
# then
#   # Neo4j 2
#   neo4j-shell -readonly -c dump | bzip2 > neo4jfulldump.cypher.bz2
#   tar -rf databases.tar neo4jfulldump.cypher.bz2
# else
#   # Neo4j 3
#   NEO4JDUMPDIR=`sudo -u neo4j mktemp -dt neo4jdump.XXXXXX` || exit 1
#   export NEO4J_USERNAME=neo4j
#   export NEO4J_PASSWORD="$NEO4J_BACKUP_PASSWORD"
#   cypher-shell --format plain "CALL apoc.export.cypher.all('$NEO4JDUMPDIR/neo4j3fulldump.cypher',{format:'cypher-shell'});" > /dev/null
#   mv "$NEO4JDUMPDIR/neo4j3fulldump.cypher" .
#   bzip2 neo4j3fulldump.cypher
#   tar -rf databases.tar neo4j3fulldump.cypher.bz2
#   rm -Rf "$NEO4JDUMPDIR" neo4j3fulldump.cypher.bz2
# fi

# postfix-virtual, postgrey
cp /etc/postfix/virtual postfix-virtual
tar -rf databases.tar postfix-virtual

# if [ -e /var/lib/postgrey/postgrey.db ] && which db_dump > /dev/null
# then
#   db_dump -p /var/lib/postgrey/postgrey.db | bzip2 > postgrey.db.txt.bz2
#   db_dump -p /var/lib/postgrey/postgrey_clients.db | bzip2 > postgrey_clients.db.txt.bz2
#   tar -rf databases.tar postgrey.db.txt.bz2 postgrey_clients.db.txt.bz2
# fi

# encrypt database dumps
eval gpg2 $BACKUPKEYS --encrypt databases.tar
tar -rf "$BACKUPFILE" databases.tar.gpg
rm -f neo4jfulldump.cypher.bz2 postfix-virtual databases.tar databases.tar.gpg



# preserve the original credentials setup file
if [ -e /root/setup/credentials.private ]
then
  cp /root/setup/credentials.private credentials.private.orig
  tar -rf serverconfig.tar credentials.private.orig
fi

# add SSH host keys (to avoid false MITM warnings)
mkdir ssh
cp /etc/ssh/ssh_host_*_key ssh/
tar -rf serverconfig.tar ssh/*

# add SSL certificates (volatile b/c letsencrypt issues new ones every other month)
mkdir le-archive
if LE_MAX=`perl -e '$a=0;for(split/\s+/,\`ls /etc/letsencrypt/archive/skgb.de\`){/^[a-z]+(\d+)\.pem$/;$b=$1||0;$a=$b if$b>$a}exit 1 if!$a;print$a;'`
then
  cp "/etc/letsencrypt/archive/skgb.de/cert$LE_MAX.pem" le-archive
  cp "/etc/letsencrypt/archive/skgb.de/chain$LE_MAX.pem" le-archive
  cp "/etc/letsencrypt/archive/skgb.de/fullchain$LE_MAX.pem" le-archive
  cp "/etc/letsencrypt/archive/skgb.de/privkey$LE_MAX.pem" le-archive
else
  echo "Backup failed: No certificates found in Let's Encrypt 'archive' directory."
  exit 1
fi
tar -rf serverconfig.tar le-archive
cp -R /etc/letsencrypt/accounts le-accounts
rm -Rf le-accounts/acme-staging*
tar -rf serverconfig.tar le-accounts
cp -R /etc/letsencrypt/renewal le-renewal
tar -rf serverconfig.tar le-renewal

# encrypt serverconfig dump
eval gpg2 $BACKUPKEYS --encrypt serverconfig.tar
tar -rf "$BACKUPFILE" serverconfig.tar.gpg
rm -Rf credentials.private.orig ssh le-archive le-accounts le-renewal serverconfig.tar serverconfig.tar.gpg



# srv.tar
# this is for:
# - volatile / transient data (such as temp/dev files)
# - large binaries that are not in repositories
# - files that are not in repositories for legal reasons

tar_append () {
  if [ -e "$2" ]
  then 
    tar -rf "$1" "$2"
  fi
}

tar -cf "$BACKUPSRVFILE" "backuptimestamp"
cd /srv
#tar -cf "$BACKUPDIR/$BACKUPSRVFILE" --exclude=Data --warning=no-file-changed *
tar_append "$BACKUPDIR/$BACKUPSRVFILE" dev/wp-config_dev.php
tar_append "$BACKUPDIR/$BACKUPSRVFILE" dev/htaccess_dev.conf
tar_append "$BACKUPDIR/$BACKUPSRVFILE" www/wp-config_www.php
tar_append "$BACKUPDIR/$BACKUPSRVFILE" www/htaccess_www.conf
tar_append "$BACKUPDIR/$BACKUPSRVFILE" www/XML
tar_append "$BACKUPDIR/$BACKUPSRVFILE" www/uploads
tar_append "$BACKUPDIR/$BACKUPSRVFILE" servo
tar_append "$BACKUPDIR/$BACKUPSRVFILE" archiv
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/skgb-intern.production.conf
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/templates/content/stegdienstliste.html.ep
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/public/Merkblatt\ Datenschutz.pdf
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/public/regeln/src-copy
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/public/lib
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" intern/lib/Mojolicious/Plugin/ReverseProxy.pm
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" Lib
tar_append "$BACKUPDIR/$BACKUPSRVFILE" legacy
# tar_append "$BACKUPDIR/$BACKUPSRVFILE" git



cd "$BACKUPDIR"
rm -f backuptimestamp
