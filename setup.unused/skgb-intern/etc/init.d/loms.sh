#! /bin/bash
### BEGIN INIT INFO
# Provides: loms
# Required-Start: $remote_fs neo4j $network
# Required-Stop: $remote_fs neo4j
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: LOMS
# Description: LOMS server daemon -aj
### END INIT INFO

# -> /etc/init.d/loms.sh
# chmod 755 /etc/init.d/loms.sh
#   insserv mydaemon
# update-rc.d loms.sh defaults
# /etc/init.d/loms.sh start

# ( cd /srv/loms && /usr/local/bin/hypnotoad ./script/myapp6.pl )


RETVAL=0

export PERLBREW_ROOT=/opt/perlbrew
export PERLBREW_HOME=/tmp/.perlbrew
source ${PERLBREW_ROOT}/etc/bashrc
##perlbrew use perl-stable
perlbrew use perl-5.22.1
#which perl

DIR="/srv/loms"
HYPNOTOAD="hypnotoad"
LOMS="script/myapp6.pl"
#APPLICATION_CONF="/usr/local/app/ping/ping.conf"
export MOJO_MODE=production
#export HYPNOTOAD_APP="/usr/local/app/ping/ping.pl"

#[ -f $APPLICATION_CONF ] || exit 3

start()
{
	echo -n $"Starting LOMS service: "
	( cd "$DIR" && $HYPNOTOAD "$LOMS" )
	#2>/dev/null
	RETVAL=$?
	echo
#	[ $RETVAL -eq 0 ] && touch /var/lock/subsys/ping || RETVAL=1
	return $RETVAL
}

stop()
{
	echo -n $"Shutting down LOMS service: "
#	pidof "$LOMS" > /dev/null && kill `pidof $LOMS`
	( cd "$DIR" && $HYPNOTOAD -s "$LOMS" )
	RETVAL=$?
#	[ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/ping
	echo
	return $RETVAL
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	reload)
		start
		;;
	restart)
		stop
		start
		;;
#	status)
#		#status ping
#		;;
	*)
		echo $"Usage: $0 {start|stop|reload|restart}"
		exit 2
esac
exit $?
