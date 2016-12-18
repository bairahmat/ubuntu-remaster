#!/bin/sh

# TODO add the kill apt instances before trying to run this.

logfile=/var/log/installer/update.log

date > $logfile

logline()
{
	echo "############################################################" >> $logfile
	echo "############################################################"
}
log()
{
	echo "############################################################" >> $logfile
	echo "# $1"                                                         >> $logfile
	echo "############################################################" >> $logfile
	echo "############################################################"
	echo "# $1"
	echo "############################################################"
}

failed()
{
	echo "############################################################" >> $logfile
	echo "# FAILED: $1"                                                 >> $logfile
	echo "############################################################" >> $logfile
	echo "############################################################"
	echo "# FAILED: $1"
	echo "############################################################"
	exit 1
}

id | grep -c uid=0 >/dev/null
if [ $? -gt 0 ]; then
	failed "You need to be root in order to run this script.."
fi

logline
log "Update: STARTING"
logline

log "Apt update"
apt-get  --allow-unauthenticated update || failed "apt update"
log "Apt autoremove/clean"
apt-get  --allow-unauthenticated -y autoremove || failed "apt-get: autoremove"
apt-get  --allow-unauthenticated -y autoclean || failed "apt-get: autoclean"
log "Apt upgrade"
apt-get --allow-unauthenticated -y dist-upgrade || fail "apt dist-upgrade"
#apt-get  --allow-unauthenticated -y upgrade || failed "apt upgrade"
log "Apt autoremove/clean"
apt-get -y autoremove || failed "apt-get: autoremove"
apt-get -y autoclean || failed "apt-get: autoclean"

logline
log "Update: COMPLETE"
logline
