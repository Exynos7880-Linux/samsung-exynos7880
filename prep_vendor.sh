#!/bin/bash

set -xe

prep_vendor () {
	mount ${1}_installer/data/vendor.img vendor
	cp -rf patches/* vendor/
	umount vendor
        e2fsck -fy ${1}_installer/data/vendor.img
}

prep_vendor "$1"
