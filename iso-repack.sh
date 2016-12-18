#!/bin/sh
#
# This script is designed to repackage an existing ISO with
# new scripts / pkg archives.  The intent is to preserve existing
# configuration and just add additional items.
#

# The Base Directory
BASEDIR="/root/installer_repack"
SHAREDIR="/media/sf_installer"

# This directory will contain files that need to be copied over
# to the new CD.
EXTRASDIR="$BASEDIR/build"

# Where the ubuntu iso image will be mounted
CDSOURCEDIR="$BASEDIR/cdsource"

# Output CD name
CDNAME="custom-repack.iso"

# Ubuntu ISO image to modify
CDIMAGE="$SHAREDIR/custom.iso"

# ------------ End of modifications.

logfile=/tmp/iso-repack.log

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
rsync -avtz --delete $CDSOURCEDIR/ $BASEDIR/FinalCD/ || failed "Rsync of cd source"

log "Copying Extra files"
rsync -avz $EXTRASDIR/ $BASEDIR/FinalCD/ || "Rsync of extra files"






logline
log "Create local apt repo for preseed post install use"
logline
# Creating local apt repo
# http://askubuntu.com/questions/170348/how-to-create-a-local-apt-repository
#
#
# alias apt-get='apt-get --allow-unauthenticated'
# apt-get update 
# apt-get install fluxbox

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
log "Configuration and package updates to base install filesystem image are SKIPPED in this script"
logline





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
