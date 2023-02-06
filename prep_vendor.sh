#!/bin/bash

set -xe

prep_vendor () {
	e2fsck -fp var/lib/lxc/android/vendor.img
	resize2fs -f var/lib/lxc/android/vendor.img 230M
	mkdir vendor
	mount var/lib/lxc/android/vendor.img vendor
	cp -rf patches/* vendor/
	umount vendor
        e2fsck -fy var/lib/lxc/android/vendor.img
}

prep_vendor "$1"
