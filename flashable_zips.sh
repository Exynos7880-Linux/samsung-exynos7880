#!/bin/bash

set -x

make_zips () {
        mv out/rootfs.img ${1}_installer/data/ubuntu.img
        cp out/boot.img ${1}_installer/boot.img
        cp out/recovery.img ${1}_installer/recovery.img
        mkdir -p var/lib/lxc/android/
	wget https://cytranet.dl.sourceforge.net/project/exynos7880/vendor/vendor.img -O var/lib/lxc/android/vendor.img
        if [ "$1" == "a7" ]; then
	   sudo ./prep_vendor.sh a7
	fi
	cd ${1}_installer
        zip -r -y -9 ../ubports-${1}y17lte-devel-`date +%Y%m%d`.zip .
        sed -i '24d' META-INF/com/google/android/updater-script
        rm recovery.img
        zip -r -y -9 ../ubports-${1}y17lte-devel-norecovery-`date +%Y%m%d`.zip .
        echo "NOW=$(date +'%Y.%m.%d'-${1}y17lte)" >> $GITHUB_ENV
}

make_zips "$1"
