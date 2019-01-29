#! /bin/bash
# kFreeBSD do not accept scripts as interpreters, using #!/bin/sh and sourcing.
if [ true != "$INIT_D_SCRIPT_SOURCED" ] ; then
    set "$0" "$@"; INIT_D_SCRIPT_SOURCED=true . /lib/init/init-d-script
fi
### BEGIN INIT INFO
# Provides:          skgb_intern2
# Required-Start:    $remote_fs neo4j $network $syslog
# Required-Stop:     $remote_fs neo4j $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: SKGB-intern 2
# Description:       SKGB-intern 2 server daemon (Mojo Hypnotoad)
#                    -aj
### END INIT INFO

# Author: Arne Johannessen <software@thaw.de>
# based on /etc/init.d/skeleton

export PERLBREW_ROOT=/opt/perlbrew
export PERLBREW_HOME=/tmp/.perlbrew
. ${PERLBREW_ROOT}/etc/bashrc
perlbrew use perl-5.28.1
#which perl
perlbrew use
HYPNOTOAD=`which hypnotoad`

LOMS_DIR="/srv/intern"
LOMS_SCRIPT="script/skgb_intern.pl"
export MOJO_MODE=production

# init-d-script config
DESC="SKGB-intern 2"
PIDFILE=/run/skgb-intern2.pid
DAEMON="$HYPNOTOAD"
DAEMON_ARGS="$LOMS_SCRIPT"

do_start_prepare () {
	cd "$LOMS_DIR"
}

do_start_cmd_override () {
	# override: hypnotoad doesn't seem to work with start-stop-daemon
	echo
	eval "$DAEMON" "$DAEMON_ARGS"
}

do_stop_prepare () {
	cd "$LOMS_DIR"
}

do_stop_cmd_override () {
	# override: hypnotoad doesn't seem to work with start-stop-daemon
	echo
	eval "$DAEMON" --stop "$DAEMON_ARGS"
}

do_reload () {
	[ "$VERBOSE" != no ] && log_daemon_msg "Reloading $DESC" "$NAME"
	call do_start_prepare
	call do_start_cmd
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
}

do_restart() {
	[ "$VERBOSE" != no ] && log_daemon_msg "Restarting $DESC" "$NAME"
	# override: init-d-script doesn't make _prepare calls m(
	call do_stop_prepare
	call do_stop_cmd
	call do_start_prepare
	call do_start_cmd
	case "$?" in
		0|1) [ "$VERBOSE" != no ] && log_end_msg 0 ;;
		2) [ "$VERBOSE" != no ] && log_end_msg 1 ;;
	esac
}

do_status_override () {
	# override: init-d-script doesn't pass along the $PIDFILE value m(
	status_of_proc -p "$PIDFILE" "$DAEMON" "$NAME" && return 0 || return $?
}

# do_test () {
# 	call do_start_prepare
# 	eval "$DAEMON" --test "$DAEMON_ARGS"
# }
# 
# do_unknown () {
# 	case "$1" in
# 	  test)
# 		call do_test
# 		;;
# 	  *)
# 		call do_usage
# 		exit 3
# 		;;
# 	esac
# 	exit 0
# }
