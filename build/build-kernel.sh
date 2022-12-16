#!/bin/bash
set -ex

TMPDOWN=$1
INSTALL_MOD_PATH=$2
HERE=$(pwd)
source "${HERE}/deviceinfo"

KERNEL_DIR="${TMPDOWN}/$(basename "${deviceinfo_kernel_source}")"
KERNEL_DIR="${KERNEL_DIR%.git}"
OUT="${TMPDOWN}/KERNEL_OBJ"

mkdir -p "$OUT"

case "$deviceinfo_arch" in
    aarch64*) ARCH="arm64" ;;
    arm*) ARCH="arm" ;;
    x86_64) ARCH="x86_64" ;;
    x86) ARCH="x86" ;;
esac

export ARCH
export CROSS_COMPILE="${deviceinfo_arch}-linux-android-"
if [ "$ARCH" == "arm64" ]; then
    export CROSS_COMPILE_ARM32=arm-linux-androideabi-
fi
MAKEOPTS=""
if [ -n "$CC" ]; then
    MAKEOPTS="CC=$CC"
fi
if [ -n "$LD" ]; then
    MAKEOPTS+=" LD=$LD"
fi

cd "$KERNEL_DIR"
make O="$OUT" $MAKEOPTS $deviceinfo_kernel_defconfig
make O="$OUT" $MAKEOPTS -j$(nproc --all)
if [ "$deviceinfo_kernel_disable_modules" != "true" ]
then
    make O="$OUT" $MAKEOPTS INSTALL_MOD_STRIP=1 INSTALL_MOD_PATH="$INSTALL_MOD_PATH" modules_install
fi
ls "$OUT/arch/$ARCH/boot/"*Image*

if [ -n "$deviceinfo_kernel_apply_overlay" ] && $deviceinfo_kernel_apply_overlay; then
    ${TMPDOWN}/ufdt_apply_overlay "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_appended_dtb}.dtb" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}.dtbo" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}-merged.dtb"
    cat "$OUT/arch/$ARCH/boot/Image.gz" \
        "$OUT/arch/arm64/boot/dts/qcom/${deviceinfo_kernel_dtb_overlay}-merged.dtb" > "$OUT/arch/$ARCH/boot/Image.gz-dtb"
fi

if [ -n "$deviceinfo_use_overlaystore" ]; then
    # Config this directory in the overlay store to override (i.e. bind-mount)
    # the whole directory. Rootfs won't ship any device-specific kernel module.
    touch "${INSTALL_MOD_PATH}/lib/modules/.halium-override-dir"
fi
