#!/bin/bash
set -xe
ARCH=arm64

[ -d build ] || git clone https://gitlab.com/ubports/community-ports/halium-generic-adaptation-build-tools -b halium-10-focal build
mkdir -p dr/downloads
git clone https://github.com/droidian/initramfs-tools-halium.git
cd initramfs-tools-halium
sudo ./build-initrd.sh -a $ARCH
cd ../
cp ./initramfs-tools-halium/out/initrd.img-touch-$ARCH ./dr/downloads/halium-boot-ramdisk.img
rm -rf initramfs-tools-halium
./build/build.sh "$@"

