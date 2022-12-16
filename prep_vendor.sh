#!/bin/bash

set -xe

prep_vendor () {
	e2fsck -fp ${1}_installer/data/vendor.img
	resize2fs -d -f ${1}_installer/data/vendor.img 230M
	mount ${1}_installer/data/vendor.img vendor
	mv -vf patches/build_${1}.prop vendor/build.prop
        mv -vf patches/odm/etc/build_${1}.prop vendor/odm/etc/build.prop
	umount vendor
        e2fsck -fy ${1}_installer/data/vendor.img
}

prep_vendor "$1"
