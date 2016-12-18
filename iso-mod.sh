#!/bin/sh
#
# This script updates a Ubuntu 16.04 iso to include additional packages and
# includes an exmaple of a preseed which does a stand alone install.  The
# preseed calls a post script setting up overlay files and uses a makedev
# tool for consistant overlay permissions.
#
######### For Reference ###########
#
# Get URIs concept
#  http://www.tuxradar.com/answers/517
#  https://help.ubuntu.com/community/AptGet/Offline/PrintUris
#    apt-get --print-uris --yes  install openssh-server | grep ^\' | cut -d\' -f2
#    apt-get --print-uris --yes  install fluxbox xorg xdm dillo | grep ^\' | cut -d\' -f2 > fluxbox_uri.htm
#    wget  --continue --input-file=../fluxbox_uri.htm
#
# ISO customizations examples
#  https://help.ubuntu.com/community/InstallCDCustomization
#  https://help.ubuntu.com/lts/installation-guide/example-preseed.txt
#  https://docs.google.com/document/d/1_4fDkd9TXQ0nUIL5Q-5W61TKrVpyS32x34GksL1uR8Q/edit#
#  https://gist.githubusercontent.com/robertstarmer/7332658/raw/00eb82b390df5c9a282db2adc32d50b652361c45/ubuntu-server.preseed
#  https://gist.githubusercontent.com/robertstarmer/5147832/raw/e87877f9f0a7758f393c11cb5afa74b443ff13a4/cd-iso-recreate.sh
#  https://www.google.com/webhp?sourceid=chrome-instant&ion=1&espv=2&ie=UTF-8#q=ubuntu+InstallCDCustomization%2FScripts
#  https://help.ubuntu.com/community/InstallCDCustomization/Scripts
#
#                                              |
# -------------- Customize starting below here |
#                                              V

# The script assumes you use a virtual machine which hosts the BASEDIR location
# and a shared network or virtual filesystem mount for SHAREDIR.
BASEDIR="/root/installer"
SHAREDIR="/media/sf_installer"

# This directory will contain files that need to be copied over
# to the new CD.
EXTRASDIR="$BASEDIR/build"

# Ubuntu ISO image
CDIMAGE="$SHAREDIR/ubuntu-16.04.1-desktop-amd64.iso"

# Where the ubuntu iso image will be mounted
CDSOURCEDIR="$BASEDIR/cdsource"

# Output CD name
CDNAME="custom.iso"

# ------------ End of modifications.

logfile=/tmp/iso-mod.log

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

################## Initial requirements
id | grep -c uid=0 >/dev/null
if [ $? -gt 0 ]; then
	failed "You need to be root in order to run this script.."
fi



logline
log "Starting folder and files setup"
logline

# Create a few directories.
if [ ! -d $BASEDIR ]; then mkdir -p $BASEDIR; fi
if [ ! -d $BASEDIR/FinalCD ]; then mkdir -p $BASEDIR/FinalCD; fi
if [ ! -z $EXTRASDIR ]; then
	if [ ! -d $EXTRASDIR ]; then mkdir -p $EXTRASDIR; fi
	if [ ! -d $EXTRASDIR/preseed ]; then mkdir -p $EXTRASDIR/preseed; fi
	if [ ! -d $EXTRASDIR/pool/extras ]; then mkdir -p $EXTRASDIR/pool/extras; fi
fi
if [ ! -d $CDSOURCEDIR ]; then mkdir -p $CDSOURCEDIR; fi

log "Rsyncing share dir content"
rsync -avz --delete $SHAREDIR/build $BASEDIR/ || failed "Rsync of share dir content"

# Check to make sure preseed files are actually valid
log "Checking preseed file syntax"
ls -la $EXTRASDIR/preseed/
debconf-set-selections -c $EXTRASDIR/preseed/* || failed "Check of seed syntax"

if [ ! -f $CDIMAGE ]; then
	wget -c http://mirror.pnl.gov/releases/16.04.1/ubuntu-16.04-desktop-amd64.iso -O $CDIMAGE
	failed "Cannot find your ubuntu image. Change CDIMAGE path."
fi

if [ ! -f $CDSOURCEDIR/md5sum.txt ]; then
	log "Mounting Ubuntu iso"
	mount | grep $CDSOURCEDIR
	if [ $? -eq 0 ]; then
		umount $CDSOURCEDIR
	fi

	mount -o loop $CDIMAGE $CDSOURCEDIR/
	if [ ! -f $CDSOURCEDIR/md5sum.txt ]; then
		failed "Mount did not succeed. Exiting."
	fi
fi

log "Resyncing cd source"
cd $BASEDIR/FinalCD
rm -f $BASEDIR/FinalCD/casper/filesystem.squashfs
mv $BASEDIR/filesystem.squashfs $BASEDIR/FinalCD/casper/
rsync -avtz --delete $CDSOURCEDIR/ $BASEDIR/FinalCD/ || failed "Rsync of cd source"

log "Copying Extra files"
rsync -avz $EXTRASDIR/ $BASEDIR/FinalCD/ || "Rsync of extra files"






logline
log "Create local apt repo for preseed post install use"
logline
# Creating local apt repo
# http://askubuntu.com/questions/170348/how-to-create-a-local-apt-repository
#
# Use of this local repo after the install will require mounting of
# the disk and using the following commands 
# alias apt-get='apt-get --allow-unauthenticated'
# apt-get update 
# apt-get install <pkg name>

cd $BASEDIR/FinalCD/cust-pkgs
dpkg-scanpackages . /dev/null > Packages
gzip --keep --force -9 Packages
# Generate the Release file
head -n 5 $BASEDIR/FinalCD/dists/xenial/Release > Release
# The Date: field has the same format as the Debian package changelog entries
echo -e "Date: `LANG=C date -R`" >> Release
# Release must contain MD5 sums of all repository files (in a simple repo just the Packages and Packages.gz files)
echo -e 'MD5Sum:' >> Release
printf ' '$(md5sum Packages.gz | cut --delimiter=' ' --fields=1)' %16d Packages.gz' $(wc --bytes Packages.gz | cut --delimiter=' ' --fields=1) >> Release
printf '\n '$(md5sum Packages | cut --delimiter=' ' --fields=1)' %16d Packages' $(wc --bytes Packages | cut --delimiter=' ' --fields=1) >> Release
# Release must contain SHA256 sums of all repository files (in a simple repo just the Packages and Packages.gz files)
echo -e '\nSHA256:' >> Release
printf ' '$(sha256sum Packages.gz | cut --delimiter=' ' --fields=1)' %16d Packages.gz' $(wc --bytes Packages.gz | cut --delimiter=' ' --fields=1) >> Release
printf '\n '$(sha256sum Packages | cut --delimiter=' ' --fields=1)' %16d Packages' $(wc --bytes Packages | cut --delimiter=' ' --fields=1) >> Release




logline
log "Create makedevs for use when copying overlays in during post install"
logline
cd $BASEDIR/FinalCD/makedevs
gcc makedevs.c -o makedevs || failed "build of makedevs"
chmod 777 makedevs

logline
log "Starting configuration and package updates to base install filesystem image"
logline

# Guidance on creating a custom squashfs
# https://nathanpfry.com/how-to-customize-an-ubuntu-installation-disc/
SQUASH_ROOT=$BASEDIR/squashfs-root

cd $BASEDIR
if [ -d $SQUASH_ROOT ]; then
	umount $SQUASH_ROOT/dev
	rm $SQUASH_ROOT -rf
fi
log "Unsquash the livecd squashfs"
unsquashfs $BASEDIR/FinalCD/casper/filesystem.squashfs || failed "Unsquash of casper"

log "Setup DNS server for chroot"
cp -f /etc/resolv.conf $SQUASH_ROOT/etc/ || failed "Copy of resolv.conf for DNS in chroot"

log "Install makedevs tool"
cp $BASEDIR/makedevs $SQUASH_ROOT/usr/bin/

log "Copy the update script into the chroot rootfs"
cp -a $SHAREDIR/update_squashfs.sh  $SQUASH_ROOT/ || failed "Copy of setup script into chroot"
chmod 777 $SQUASH_ROOT/update_squashfs.sh

log "Setup and enter the chroot"
mount --bind /dev/ $SQUASH_ROOT/dev || failed "Bind mount of dev for squash chroot"
chroot $SQUASH_ROOT /bin/bash -c "/update_squashfs.sh"
rm -f $SQUASH_ROOT/update_squashfs.sh

log "Exited the chroot so update the fs manifest"
umount $SQUASH_ROOT/dev || failed "Bind umount of dev for squash chroot"
chmod +w $BASEDIR/FinalCD/casper/filesystem.manifest
chroot  $SQUASH_ROOT dpkg-query -W --showformat='${Package} ${Vion}n' | tee $BASEDIR/FinalCD/casper/filesystem.manifest  &> /dev/null

log "Removing old squashfs"
mv $BASEDIR/FinalCD/casper/filesystem.squashfs $BASEDIR/

log "Make new squashfs"
mksquashfs $SQUASH_ROOT $BASEDIR/FinalCD/casper/filesystem.squashfs -b 1048576 || failed "Making new squashfs"

log "Calc squashfs size"
printf $(du -sx --block-size=1 $SQUASH_ROOT | cut -f1) | tee $BASEDIR/FinalCD/casper/filesystem.size





logline
log "Starting ISO recreation steps"
logline

log "Updating md5 checksums"
cd $BASEDIR/FinalCD
chmod 666 md5sum.txt
rm -f md5sum.txt
find . -type f -print0 | xargs -0 md5sum > md5sum.txt

log "Creating and ISO image..."
cd $BASEDIR/FinalCD
mkisofs -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -J -hide-rr-moved -o $SHAREDIR/$CDNAME -R $BASEDIR/FinalCD/  || failed "Making new iso"

logline
log "CD Available in $SHAREDIR/$CDNAME"
logline
