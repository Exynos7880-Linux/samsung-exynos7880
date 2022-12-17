#!/bin/bash

set -xe

prep_vendor () {
	e2fsck -fp ${1}_installer/data/vendor.img
	resize2fs -f ${1}_installer/data/vendor.img 230M
	mkdir vendor
	mount ${1}_installer/data/vendor.img vendor
	cp -rf patches/* vendor/
	umount vendor
        e2fsck -fy ${1}_installer/data/vendor.img
}

prep_vendor "$1"
