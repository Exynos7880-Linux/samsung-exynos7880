#!/bin/bash
set -ex

TMPDOWN=$(realpath $1)
KERNEL_OBJ=$(realpath $2)
OUT=$(realpath $3)

HERE=$(pwd)
source "${HERE}/deviceinfo"

case "$deviceinfo_arch" in
    aarch64*) ARCH="arm64" ;;
    arm*) ARCH="arm" ;;
    x86_64) ARCH="x86_64" ;;
    x86) ARCH="x86" ;;
esac

if [ -n "$deviceinfo_dtbo" ]; then
    PREFIX=$KERNEL_OBJ/arch/$ARCH/boot/dts/
    DTBO_LIST="$PREFIX${deviceinfo_dtbo// / $PREFIX}"
else
    echo "Please define deviceinfo_dtbo in deviceinfo"
    exit 1
fi

python2 "$TMPDOWN/libufdt/utils/src/mkdtboimg.py" create "$OUT" $DTBO_LIST
