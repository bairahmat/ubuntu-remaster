#!/bin/sh
#


logfile=/tmp/update_squashfs.log

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
	cleanup
	exit 1
}

id | grep -c uid=0 >/dev/null
if [ $? -gt 0 ]; then
	failed "You need to be root in order to run this script.."
fi


cleanup()
{
	log "Cleanup tmp files"
	rm -rf /tmp/* ~/.bash_history
	rm /var/lib/dbus/machine-id
	rm /sbin/initctl
	dpkg-divert --rename --remove /sbin/initctl || failed "dpkg-divert remove"

	log "Remove mounts"
	umount /proc || umount -lf /proc
	umount /sys     || failed "umount sys"
	umount /dev/pts || failed "umount pts"

}



log "Setup mounts"
mount -t proc none /proc      || failed "Mount of proc"
mount -t sysfs none /sys      || failed "Mount of sys"
mount -t devpts none /dev/pts || failed "Mount of pts"

log "Setup env"
export HOME=/root
export LC_ALL=C
dbus-uuidgen > /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl || failed "dpkg-divert add"
ln -s /bin/true /sbin/initctl

log "Setup apt sources.list"
mv /etc/apt/sources.list /etc/apt/sources.list.orig
cat <<EOM > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ xenial main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ xenial main restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates main restricted
deb-src http://us.archive.ubuntu.com/ubuntu/ xenial-updates main restricted
deb http://us.archive.ubuntu.com/ubuntu/ xenial universe
deb-src http://us.archive.ubuntu.com/ubuntu/ xenial universe
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates universe
deb http://us.archive.ubuntu.com/ubuntu/ xenial multiverse
deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates multiverse
deb http://us.archive.ubuntu.com/ubuntu/ xenial-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu xenial-security main restricted
deb http://security.ubuntu.com/ubuntu xenial-security universe
deb http://security.ubuntu.com/ubuntu xenial-security multiverse
EOM

log "App apt arch i386"
dpkg --add-architecture i386 || failed "Adding i386 arch to dpkg"

log "Apt update"
add-apt-repository -y ppa:mystic-mirage/pycharm || failed "add repo: pycharm"
apt-get update || failed "apt-get: update"

log "Apt purge"
# Check what's installed to help build the list
# dpkg --get-selections | grep -v deinstall
pkgs_purge="network-manager"
apt-get -y purge $pkgs_purge || failed "apt-get: purge"


log "TODO: ADD additional pkgs HERE for other GUI apps"

log "Apt install"
pkgs_core=" \
   libc6:i386 \
   libstdc++6:i386 \
   nfs-common \
   cifs-utils \
   samba \
   vim \
   htop \
   tofrodos \
   screen \
   graphviz \
   device-tree-compiler \
   bison flex gettext texinfo patch git libncurses5-dev ncurses-dev \
   gperf libtool automake aptitude gawk build-essential zlib1g-dev \
   libexpat1-dev cvs autopoint xorriso curl git unzip \
   python-matplotlib python-numpy mercurial subversion cscope"
# TODO  libpam-smbpass is broken
#pkgs_ldap="libnss-ldap libpam-ldap ldap-utils libpam-smbpass libsmbclient"
pkgs_gui=" \
   gpm \
   lsb \
   socat \
   iperf  \
   iperf3 \
   libvisa-dev \
   gdb \
   python-dev \
   python2.7-dbg \
   gtk2-engines-pixbuf \
   zlib1g-dev:i386 \
   gcc-multilib \
   python-crypto python-serial python-ecdsa python-paramiko python-wxgtk3.0 \
   python-pip \
   pycharm-community openjdk-8-jre"
apt-get -y install $pkgs_core || failed "apt-get: install core"
apt-get -y install $pkgs_ldap || failed "apt-get: install ldap"
apt-get -y install $pkgs_gui || failed "apt-get: install gui"
pip install gui2py || failed "pip: install gui2py"

# asciidoc auto hardware graphic generation
pip install pyfdt || failed "pip: install pyfdt"

log "Apt autoremove"
apt-get -y autoremove || failed "apt-get: autoremove"

log "Apt autoclean"
apt-get -y autoclean || failed "apt-get: autoclean"

log "Restore original apt sources.list"
mv /etc/apt/sources.list /etc/apt/sources.list.stock
mv /etc/apt/sources.list.orig /etc/apt/sources.list

log "Make mount point for future DVD install use"
mkdir -p /media/cdrom

cleanup
