#! /bin/bash
#set -e
#set -x

# Create the backup tarball and store it locally.
# Inverse script: backupimport.sh


BACKUPDIR=/root/backups
BACKUPFILE=clydebackup.tar
BACKUPKEYS='-r 75EB52B0 -r 260EC33C'  # Arne + SKGB Automated Backups
BACKUPSRVFILE=clydesrv.tar
#BACKUPMYSQLDBS='skgb_intern skgb_web db10959533-wordpressdev'
BACKUPMYSQLDBS='postfix skgb_web'

MYSQL_BACKUP_PASSWORD=


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
tar -rf "$BACKUPFILE" installed-versions.log
rm -f installed-versions.log

#perldoc -oText perllocal 2>&1 | grep '"Module"\|VERSION\|install \|"perllocal"' > installed-modules.log
#for M in `perldoc -t perllocal | grep '"Module"' | sed -e 's/^.*" //'`
#do
#	V=`perldoc -t perllocal | awk "/$M/{y=1;next}y" | grep VERSION | head -n 1`
#	echo "$M $V"
#done | sort -b > installed-modules.log
#tar -rf catbackup.tar installed-modules.log
#rm -f installed-modules.log

# file catalogue
# we don't usually need this either, but it may come in very handy in case of catastrophic failure
find / | grep -v '^/boot/\|^/dev/\|^/sys/\|^/proc/\|^/root/\.cpan/' &> cata.log
bzip2 -c cata.log > cata.log.bz2
tar -rf "$BACKUPFILE" cata.log.bz2
rm -f cata.log cata.log.bz2

# do a mysql dump
#--all-databases
eval mysqldump --user=backup $MYSQL_BACKUP_PASSWORD --events --no-data --databases $BACKUPMYSQLDBS | bzip2 > mysqlstructure.sql.bz2
eval mysqldump --user=backup $MYSQL_BACKUP_PASSWORD --events --no-create-info --databases $BACKUPMYSQLDBS | bzip2 > mysqldata.sql.bz2
# (--events is just used to suppress a useless warning message; we don't actually use events. Also, the events privilege needs to be enabled for the backup mysql user for this hack to work.)
tar -rf "$BACKUPFILE" mysqlstructure.sql.bz2
tar -cf databases.tar mysqldata.sql.bz2
rm -f mysqlstructure.sql.bz2 mysqldata.sql.bz2

# red-legacy db
cd /srv
tar -rf "$BACKUPDIR/databases.tar" Data
cd "$BACKUPDIR"

# do a neo4j dump
if which neo4j-shell > /dev/null
then
	# Neo4j 2
	neo4j-shell -readonly -c dump | bzip2 > neo4jfulldump.cypher.bz2
	tar -rf databases.tar neo4jfulldump.cypher.bz2
else
	# Neo4j 3
	NEO4JDUMPDIR=`sudo -u neo4j mktemp -dt neo4jdump.XXXXXX` || exit 1
	sudo -u neo4j neo4j-admin dump --to="$NEO4JDUMPDIR/graph.db.dump"
	mv "$NEO4JDUMPDIR/graph.db.dump" .
	tar -rf databases.tar graph.db.dump
	rm -Rf "$NEO4JDUMPDIR"
	# possible alternative: APOC, see <https://neo4j.com/developer/kb/export-sub-graph-to-cypher-and-import/>
fi

# copy the virtual alias table
# (technically not a database, but the easiest way is to treat it like one anyway)
cp /etc/postfix/virtual postfix-virtual
tar -rf databases.tar postfix-virtual

# encrypt database dumps
eval gpg2 $BACKUPKEYS --encrypt databases.tar
tar -rf "$BACKUPFILE" databases.tar.gpg
rm -f neo4jfulldump.cypher.bz2 postfix-virtual databases.tar databases.tar.gpg



# preserve the original credentials setup file
cp /root/clydesetup/credentials.private credentials.private.orig
tar -cf serverconfig.tar credentials.private.orig

# add SSL certificates (volatile b/c letsencrypt issues new ones every other month)
#cp /root/clydesetup/credentials.private credentials.private.orig
#tar -cf serverconfig.tar credentials.private.orig
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
rm -Rf credentials.private.orig le-archive le-accounts le-renewal serverconfig.tar serverconfig.tar.gpg



# this is basically for volatile / transient data only

# include non-transient data like apache document roots? -> NO!, these are pulled from outside sources like repositories by the setup routines (should be, anyway - TODO)
cd /srv
tar -cf "$BACKUPDIR/$BACKUPSRVFILE" --exclude=Data --warning=no-file-changed *
cd "$BACKUPDIR"
# ./.
# how about stuff that may be sloppily changed on Clyde only, but not in the rep? 

# - data that is non-transient, but not part of any repository?
# - any data that's usually changed on the server only?
# - other transient data?



rm -f backuptimestamp
