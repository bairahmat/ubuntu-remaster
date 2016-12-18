#!/bin/sh
#

logfile=/var/log/installer/mkServer.log

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
log "Setup Server: STARTING"
logline

log "Apt update"
apt-get --allow-unauthenticated update

log "Apt purge"
pkgs_purge=" \
   ubuntu-desktop \
   lightdm unity \
   libreoffice-common \
   pycharm-community "
apt-get -y purge $pkgs_purge || failed "apt-get: purge"

log "Apt install"
pkgs_core=" \
   nfs-kernel-server \
   samba"
apt-get --allow-unauthenticated -y install $pkgs_core || failed "apt-get: install"

#log "Apt upgrade"
#apt-get --allow-unauthenticated -y upgrade || failed "apt-get: upgrade"

log "Apt autoremove"
apt-get -y autoremove || failed "apt-get: autoremove"

log "Apt autoclean"
apt-get -y autoclean || failed "apt-get: autoclean"

logline
log "Setup Server: COMPLETE"
logline
