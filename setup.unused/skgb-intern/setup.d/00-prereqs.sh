#!bash


# Extra prerequisite: The OpenPGP key pair (public AND private key) for
# the automated backups. This key is used by /root/backup/import.sh to
# decrypt the contents of backup.tar later.

echo -n "Checking for backupkey.private ... "
if [ -e "$SETUPPATH/backupkey.private" ]
then
  echo "is present."
  # move key in place for 41-backups.sh:
  mv -v "$SETUPPATH/backupkey.private" "$SETUPPATH/root/.gnupg/260EC33C-sec.asc"
  
else
  echo "is missing!"
  SETUPFAIL=1
  [ -z "$SETUP_DRY_RUN" ] && false  # abort execution if  set -e  is in use
fi

