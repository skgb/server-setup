#! /bin/bash
#set -e
#set -x

# Create the backup tarball and store it locally.
# Inverse script: backupimport.sh


BACKUPDIR=/root/backups
BACKUPFILE=clydebackup.tar
BACKUPKEYS='-r 75EB52B0 -r EF330646'  # Arne + Clyde Automated Backup Test
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
/usr/bin/neo4j-shell -readonly -c dump | bzip2 > neo4jfulldump.cypher.bz2
tar -rf databases.tar neo4jfulldump.cypher.bz2

# copy the virtual alias table
# (technically not a database, but the easiest way is to treat it like one anyway)
cp /etc/postfix/virtual postfix-virtual
tar -rf databases.tar postfix-virtual

# encrypt database dumps
eval gpg2 $BACKUPKEYS --encrypt databases.tar
tar -rf "$BACKUPFILE" databases.tar.gpg
rm -f neo4jfulldump.cypher.bz2 postfix-virtual databases.tar databases.tar.gpg



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
