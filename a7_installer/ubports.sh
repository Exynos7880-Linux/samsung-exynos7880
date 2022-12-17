
OUTFD=/proc/self/fd/$1;

# ui_print <text>
ui_print() { echo -e "ui_print $1\nui_print" > $OUTFD; }


ui_print "Resizing rootfs to 8GB";
e2fsck -fy /data/ubuntu.img
e2fsck -fy /data/vendor.img
resize2fs /data/ubuntu.img 8G

## end install
