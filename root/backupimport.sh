#! /bin/bash
#set -e
#set -x

BACKUPFILE=clydebackup.tar

if (whoami | grep -qv '^root$') ; then
	echo "Usage: `basename $0` $BACKUPFILE -y"
	echo "Execute as root!"
	exit 1
fi
if [[ $# -lt 2 || $# -gt 2 || ("$2" != "-y") ]] ; then
	echo "Usage: `basename $0` $BACKUPFILE -y"
	exit 1
fi

SCRIPTNAME=`basename "$0" '.sh'`
TARBALL=`readlink -m $1`
#if [ ! -f "$TARBALL" ] ; then
#	SCRIPTPWD=`pwd`
#	TARBALL="$SCRIPTPWD/$TARBALL"
#fi
if [ ! -f "$TARBALL" ] ; then
	echo "$SCRIPTNAME: $1: Cannot open: No such file or directory" 1>&2
	echo "$SCRIPTNAME: Error is not recoverable: exiting now" 1>&2
	echo
	exit 1
fi

BACKUPDIR=`mktemp -dt "${SCRIPTNAME}.XXXXXX"` || exit 1
echo "created directory: '$BACKUPDIR'"
cd "$BACKUPDIR"
tar -xf "$TARBALL" || exit 1

echo -n "importing backup"
[ -e "backuptimestamp" ] && echo -n " '`cat backuptimestamp`'"
echo

if [ -f databases.tar.gpg ] ; then
	sleep 1  # give user time to read the intro
	gpg2 databases.tar.gpg || exit 1
fi
if [ -f databases.tar ] ; then
	tar -xf databases.tar
fi

bunzip2 -c mysqlstructure.sql.bz2 | mysql --user=root
bunzip2 -c mysqldata.sql.bz2 | mysql --user=root
mysqladmin flush-privileges

mv -v postfix-virtual /etc/postfix/virtual
/etc/postfix/reload

bunzip2 neo4jfulldump.cypher.bz2
echo "Cleaning Neo4j database:"
/usr/bin/neo4j-shell -c 'MATCH (n) DETACH DELETE n;'
if [ `du -b neo4jfulldump.cypher | cut -f1` -ne 15 ] ; then
	# Importing this will cause an "Unknown command ;" error if the dump happens to be empty. As of neo4j 2.3.3, empty dumps have a size of 15 bytes, exactly.
	echo "Neo4j database import:"
	/usr/bin/neo4j-shell -file neo4jfulldump.cypher
else
	echo "Neo4j database dump empty; import skipped."
fi

chown -R www-data:www-data Data
chmod -R go-rwx Data
rm -Rf /srv/Data/*
mv Data /srv

rm -Rf "$BACKUPDIR"/*
rm -Rvf "$BACKUPDIR"

exit 0
