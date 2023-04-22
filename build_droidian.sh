#!/bin/bash
set -xe
[ -d build ] || git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools -b halium-10-focal build
mkdir -p dr/downloads
mv initrd.img-halium-generic ./dr/downloads/halium-boot-ramdisk.img
./build/build.sh "$@"

