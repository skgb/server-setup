#! /bin/bash
#set -e
#set -x

BACKUPFILE=backup.tar

if (whoami | grep -qv '^root$') ; then
  echo "Usage: `basename $0` $BACKUPFILE -y"
  echo "Execute as root!"
  exit 1
fi
# if [ -z "$NEO4J_PASSWORD" ] ; then
#   echo "Usage: `basename $0` $BACKUPFILE -y"
#   echo "Provide \$NEO4J_PASSWORD in the environment!"
#   exit 1
# fi
if [[ $# -lt 2 || $# -gt 2 || ("$2" != "-y") ]] ; then
  echo "Usage: `basename $0` $BACKUPFILE -y"
  exit 1
fi

SCRIPTNAME=`basename "$0" '.sh'`
TARBALL=`readlink -m $1`
#if [ ! -f "$TARBALL" ] ; then
#  SCRIPTPWD=`pwd`
#  TARBALL="$SCRIPTPWD/$TARBALL"
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

sleep 1  # give user time to see the intro
if [ -f databases.tar.gpg ] ; then
  gpg databases.tar.gpg || exit 1
fi
if [ -f serverconfig.tar.gpg ] ; then
  gpg serverconfig.tar.gpg || exit 1
fi
if [ -f serverconfig.tar.bz2 ] ; then
  bunzip2 serverconfig.tar.bz2
fi
if [ -f databases.tar ] ; then
  tar -xf databases.tar
fi
if [ -f serverconfig.tar ] ; then
  tar -xf serverconfig.tar
fi



mysql <<EOF
CREATE DATABASE IF NOT EXISTS postfix DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS skgb_web DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS skgb_dev DEFAULT CHARACTER SET utf8mb4;
EOF
bunzip2 -c mysql_postfix.sql.bz2 | mysql --user=root postfix
bunzip2 -c mysql_skgb_web.sql.bz2 | mysql --user=root skgb_web
bunzip2 -c mysql_skgb_web.sql.bz2 | mysql --user=root skgb_dev
mysqladmin flush-privileges

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
apply_database_fix skgb_dev root     ''                       https://dev.skgb.de "SKGB-Web Dev"
#apply_database_fix skgb_dev skgb-dev "$MYSQL_WP_DEV_PASSWORD" https://dev.skgb.de "SKGB-Web Dev"



mkdir -p /etc/postfix
mv -v postfix-virtual /etc/postfix/virtual
[ -f "/etc/postfix/reload" ] && /etc/postfix/reload

# echo "Restoring postgrey db..."
# if [ -e postgrey.db.txt.bz2 ]
# then
#   mkdir -p /var/lib/postgrey
#   bunzip2 -c postgrey.db.txt.bz2 | db_load /var/lib/postgrey/postgrey.db
#   bunzip2 -c postgrey_clients.db.txt.bz2 | db_load /var/lib/postgrey/postgrey_clients.db
#   chown -R postgrey:postgrey /var/lib/postgrey
# #  chown postgrey:postgrey /var/lib/postgrey/postgrey.db /var/lib/postgrey/postgrey_clients.db
#   chmod 700 /var/lib/postgrey
#   chmod 600 /var/lib/postgrey/postgrey.db /var/lib/postgrey/postgrey_clients.db
# else
#   echo "(not present in $BACKUPFILE -- skipped!)"
# fi

# echo "Cleaning Neo4j database:"
# cypher-shell -u neo4j --format verbose 'MATCH (n) DETACH DELETE n;'
# if [ -f neo4j3fulldump.cypher.bz2 ] ; then
#   bunzip2 neo4j3fulldump.cypher.bz2
#   cp neo4j3fulldump.cypher /root
#   cypher-shell -u neo4j --format verbose < neo4j3fulldump.cypher
# elif [ -f neo4jfulldump.cypher.bz2 ] ; then
#   bunzip2 neo4jfulldump.cypher.bz2
#   if [ `du -b neo4jfulldump.cypher | cut -f1` -ne 15 ] ; then
#     # Importing this will cause an "Unknown command ;" error if the dump happens to be empty. As of neo4j 2.3.3, empty dumps have a size of 15 bytes, exactly.
#     echo "Neo4j database import:"
#     # Neo4j 2.x exports have a different syntax than what the 3.x cypher-shell requires
#     sed -e '/^begin$/s//:begin/' -e '/^commit$/s//:commit/' -e '/^create \(_[0-9]*\)-/s//create (\1)-/' -e '/->\(_[0-9]*\)$/s//->(\1)/' < neo4jfulldump.cypher > neo4j3fulldump.cypher
#     cp neo4j3fulldump.cypher /root
#     cypher-shell -u neo4j --format verbose < neo4j3fulldump.cypher
#   else
#     echo "Neo4j database dump empty; import skipped."
#   fi
# elif [ -f graph.db.dump ] ; then
#   systemctl stop neo4j
#   sleep 2  # wait for Neo4j to shut down
#   #sudo -u neo4j
#   neo4j-admin load --from=graph.db.dump --database=graph.db --force
#   systemctl start neo4j
# else
#   echo "No Neo4j database dump found in import data; skipped."
# fi

# chown -R www-data:www-data Data
# chmod -R go-rwx Data
# rm -Rf /srv/Data/*
# mv Data /srv



echo "Importing SSH host keys..."

shopt -s nullglob  # avoid literal '*' in case of no results
for f in ssh/*
do
  c=`ssh-keygen -lf "$f" | cut -d ' ' -f 3`
  ssh-keygen -yf "$f" | sed -e "1s/\$/ $c/" > "/etc/$f.pub"
  echo "writing public key '/etc/$f.pub'"
  mv -v "$f" "/etc/$f"
  chmod 644 "/etc/$f.pub"
  chmod 600 "/etc/$f"
done
systemctl reload sshd



echo "Importing Let's Encrypt accounts and certificates..."

mkdir -p /etc/letsencrypt/accounts
chmod 700 /etc/letsencrypt/accounts
for a in le-accounts/* ; do
  ACME_API=/etc/letsencrypt/accounts/`basename "$a"`
  echo "$ACME_API"
  rm -Rf "$ACME_API"
  mv -v "$a" "$ACME_API"
done
mkdir -p /etc/letsencrypt/archive/skgb.de
chmod 700 /etc/letsencrypt/archive
mv le-archive/* /etc/letsencrypt/archive/skgb.de
mkdir -p /etc/letsencrypt/renewal
mv le-renewal/skgb.de.conf /etc/letsencrypt/renewal

if [ -f /etc/letsencrypt/live/skgb.de/cert.pem ] ; then
  echo "Let's Encrypt 'live' links already exist; skipped."
  echo "You must manually verify that these links point to the correct certificates!"
  ls -l /etc/letsencrypt/live/skgb.de/*.pem | cut -d' ' -f9-
elif LE_MAX=`perl -e '$a=0;for(split/\s+/,\`ls /etc/letsencrypt/archive/skgb.de\`){/^[a-z]+(\d+)\.pem$/;$b=$1||0;$a=$b if$b>$a}exit 1 if!$a;print$a;'` ; then
  mkdir -p /etc/letsencrypt/live/skgb.de
  chmod 700 /etc/letsencrypt/live
  ln -s "../../archive/skgb.de/cert$LE_MAX.pem" /etc/letsencrypt/live/skgb.de/cert.pem
  ln -s "../../archive/skgb.de/chain$LE_MAX.pem" /etc/letsencrypt/live/skgb.de/chain.pem
  ln -s "../../archive/skgb.de/fullchain$LE_MAX.pem" /etc/letsencrypt/live/skgb.de/fullchain.pem
  ln -s "../../archive/skgb.de/privkey$LE_MAX.pem" /etc/letsencrypt/live/skgb.de/privkey.pem
else
  echo "No certificates found in Let's Encrypt 'archive' directory."
fi



rm -Rf "$BACKUPDIR"/*
rm -Rvf "$BACKUPDIR"

exit 0
