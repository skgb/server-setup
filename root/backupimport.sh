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

echo "Cleaning Neo4j database:"
cypher-shell -u neo4j --format verbose 'MATCH (n) DETACH DELETE n;'
if [ -f neo4jfulldump.cypher.bz2 ] ; then
	bunzip2 neo4jfulldump.cypher.bz2
	if [ `du -b neo4jfulldump.cypher | cut -f1` -ne 15 ] ; then
		# Importing this will cause an "Unknown command ;" error if the dump happens to be empty. As of neo4j 2.3.3, empty dumps have a size of 15 bytes, exactly.
		echo "Neo4j database import:"
		# Neo4j 2.x exports have a different syntax than what the 3.x cypher-shell requires
		sed -e '/^begin$/s//:begin/' -e '/^commit$/s//:commit/' -e '/^create \(_[0-9]*\)-/s//create (\1)-/' -e '/->\(_[0-9]*\)$/s//->(\1)/' < neo4jfulldump.cypher > neo4j3fulldump.cypher
		cp neo4j3fulldump.cypher /root
		cypher-shell -u neo4j --format verbose < neo4j3fulldump.cypher
	else
		echo "Neo4j database dump empty; import skipped."
	fi
elif [ -f graph.db.dump ] ; then
	systemctl stop neo4j
	sleep 2  # wait for Neo4j to shut down
	#sudo -u neo4j
	neo4j-admin load --from=graph.db.dump --database=graph.db --force
	systemctl start neo4j
else
	echo "No Neo4j database dump found in import data; skipped."
fi

chown -R www-data:www-data Data
chmod -R go-rwx Data
rm -Rf /srv/Data/*
mv Data /srv

rm -Rf "$BACKUPDIR"/*
rm -Rvf "$BACKUPDIR"

exit 0
