#! /bin/bash


REMOTE_USER=skgb
REMOTE_HOST=cat.johannessen.de

BANDWIDTH=200000  # kbit/s

if [ "$1" = "--quiet" ]
then QUIET="-q"
else QUIET=
fi

scp -l $BANDWIDTH $QUIET -p -B -i /root/.ssh/id_ed25519_backup \
/root/backups/clydebackup.tar.1 \
"$REMOTE_USER@$REMOTE_HOST":backup/clydebackup.tar

scp -l $BANDWIDTH $QUIET -p -B -i /root/.ssh/id_ed25519_backup \
/root/backups/clydesrv.tar \
"$REMOTE_USER@$REMOTE_HOST":backup/clydesrv.tar
