#! /bin/bash


if [[ $# -lt 1 ]] ; then
	echo "Usage: `basename $0` <cypher-file>"
	exit 1
fi

. /root/backupcredentials

NEO4J_PASSWORD="$NEO4J_BACKUP_PASSWORD" \
cypher-shell --format verbose -u neo4j < $1
