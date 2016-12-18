
Start with the iso-mod.sh script and update the initial 
few variables to setup the environment.  This script
will create a customized iso.  If you need to modify the
default squashfs package list, edit the lists in the 
update_squashfs.sh script.  This script is used by the
iso-mod.sh script.

The iso-repack.sh can be used to update the cust-pkgs list
and the preseed files in the iso without reworking the
squashfs part to add packages to the initial fs install.

The rufus tool version 2.11 has been tested to work with
imaging the iso do a USB stick.
