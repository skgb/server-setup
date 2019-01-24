#! /bin/bash

SETUPROOT=clydesetup
SETUPFILE=clydesetup/clydesetup.tar


# prepare the setup archive for deployment based on a local copy on OS X

# TODO: make this script pull a fresh copy from the git repo on the server


SCRIPTPWD=`pwd`
SCRIPTPATH=`dirname "$0"`
cd "$SCRIPTPWD/$SCRIPTPATH/.."
pwd

# prevent inclusion of resource forks
export COPYFILE_DISABLE=true

echo -n "rm: "
rm -v "$SETUPFILE"
tar -cLvf "$SETUPFILE" "$SETUPROOT/setup.sh"

tar -rLvf "$SETUPFILE" --exclude .DS_Store "$SETUPROOT/etc"
tar -rLvf "$SETUPFILE" --exclude .DS_Store "$SETUPROOT/root"
tar -rLvf "$SETUPFILE" --exclude .DS_Store "$SETUPROOT/srv"
tar -rLvf "$SETUPFILE" "$SETUPROOT/installed-software.log"

tar -rLvf "$SETUPFILE" "$SETUPROOT/README.md"
tar -rLvf "$SETUPFILE" "$SETUPROOT/hostkeys.sh"


# manually on server:

# cd /root
# tar -xf clydesetup.tar --no-same-owner --no-same-permissions
# mv clydebackup.tar clydesetup
# mv clydesrv.tar.gz clydesetup
