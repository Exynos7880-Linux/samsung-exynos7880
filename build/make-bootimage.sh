#!/bin/bash
set -ex

TMPDOWN=$(realpath $1)
KERNEL_OBJ=$(realpath $2)
RAMDISK=$(realpath $3)
OUT=$(realpath $4)

HERE=$(pwd)
source "${HERE}/deviceinfo"

case "$deviceinfo_arch" in
    aarch64*) ARCH="arm64" ;;
    arm*) ARCH="arm" ;;
    x86_64) ARCH="x86_64" ;;
    x86) ARCH="x86" ;;
esac

[ -f "$HERE/ramdisk-recovery.img" ] && RECOVERY_RAMDISK="$HERE/ramdisk-recovery.img"
[ -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ] && RECOVERY_RAMDISK="$HERE/ramdisk-overlay/ramdisk-recovery.img"

if [ -d "$HERE/ramdisk-recovery-overlay" ] && [ -e "$RECOVERY_RAMDISK" ]; then
    rm -rf "$TMPDOWN/ramdisk-recovery"
    mkdir -p "$TMPDOWN/ramdisk-recovery"

    cd "$TMPDOWN/ramdisk-recovery"
    fakeroot -- bash <<EOF
gzip -dc "$RECOVERY_RAMDISK" | cpio -i
cp -r "$HERE/ramdisk-recovery-overlay"/* "$TMPDOWN/ramdisk-recovery"

# Set values in prop.default based on deviceinfo
echo "#" >> prop.default
echo "# added by halium-generic-adaptation-build-tools" >> prop.default
echo "ro.product.brand=$deviceinfo_manufacturer" >> prop.default
echo "ro.product.device=$deviceinfo_codename" >> prop.default
echo "ro.product.manufacturer=$deviceinfo_manufacturer" >> prop.default
echo "ro.product.model=$deviceinfo_name" >> prop.default
echo "ro.product.name=halium_$deviceinfo_codename" >> prop.default

find . | cpio -o -H newc | gzip > "$TMPDOWN/ramdisk-recovery.img-merged"
EOF
    if [ ! -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ]; then
        RECOVERY_RAMDISK="$TMPDOWN/ramdisk-recovery.img-merged"
    else
        mv "$HERE/ramdisk-overlay/ramdisk-recovery.img" "$TMPDOWN/ramdisk-recovery.img-original"
        cp "$TMPDOWN/ramdisk-recovery.img-merged" "$HERE/ramdisk-overlay/ramdisk-recovery.img"
    fi
fi

if [ -d "$HERE/ramdisk-overlay" ]; then
    cp "$RAMDISK" "${RAMDISK}-merged"
    RAMDISK="${RAMDISK}-merged"
    cd "$HERE/ramdisk-overlay"
    find . | cpio -o -H newc | gzip >> "$RAMDISK"

    # Restore unoverlayed recovery ramdisk
    if [ -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ] && [ -f "$TMPDOWN/ramdisk-recovery.img-original" ]; then
        mv "$TMPDOWN/ramdisk-recovery.img-original" "$HERE/ramdisk-overlay/ramdisk-recovery.img"
    fi
fi

if [ -n "$deviceinfo_kernel_image_name" ]; then
    KERNEL="$KERNEL_OBJ/arch/$ARCH/boot/$deviceinfo_kernel_image_name"
else
    # Autodetect kernel image name for boot.img
    if [ "$deviceinfo_bootimg_header_version" -eq 2 ]; then
        IMAGE_LIST="Image.gz Image"
    else
        IMAGE_LIST="Image.gz-dtb Image.gz Image"
    fi

    for image in $IMAGE_LIST; do
        if [ -e "$KERNEL_OBJ/arch/$ARCH/boot/$image" ]; then
            KERNEL="$KERNEL_OBJ/arch/$ARCH/boot/$image"
            break
        fi
    done
fi

if [ -n "$deviceinfo_bootimg_prebuilt_dtb" ]; then
    DTB="$HERE/$deviceinfo_bootimg_prebuilt_dtb"
elif [ -n "$deviceinfo_dtb" ]; then
    DTB="$KERNEL_OBJ/../$deviceinfo_codename.dtb"
    PREFIX=$KERNEL_OBJ/arch/$ARCH/boot/dts/
    DTBS="$PREFIX${deviceinfo_dtb// / $PREFIX}"
    cat $DTBS > $DTB
fi

if [ -n "$deviceinfo_bootimg_prebuilt_dt" ]; then
    DT="$HERE/$deviceinfo_bootimg_prebuilt_dt"
fi

if [ -n "$deviceinfo_prebuilt_dtbo" ]; then
    DTBO="$HERE/$deviceinfo_prebuilt_dtbo"
elif [ -n "$deviceinfo_dtbo" ]; then
    DTBO="$(dirname "$OUT")/dtbo.img"
fi

EXTRA_ARGS=""

if [ "$deviceinfo_bootimg_header_version" -le 2 ]; then
    EXTRA_ARGS+=" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize"
fi

if [ "$deviceinfo_bootimg_header_version" -eq 0 ] && [ -n "$DT" ]; then
    EXTRA_ARGS+=" --dt $DT"
fi

if [ "$deviceinfo_bootimg_header_version" -eq 2 ]; then
    EXTRA_ARGS+=" --dtb $DTB --dtb_offset $deviceinfo_flash_offset_dtb"
fi

if [ -n "$deviceinfo_bootimg_board" ]; then
    EXTRA_ARGS+=" --board $deviceinfo_bootimg_board"
fi

mkbootimg --kernel "$KERNEL" --ramdisk "$RAMDISK" --cmdline "$deviceinfo_kernel_cmdline" --header_version $deviceinfo_bootimg_header_version -o "$OUT" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS

if [ -n "$deviceinfo_bootimg_partition_size" ]; then
    if [ "$deviceinfo_bootimg_tailtype" == "SEAndroid" ]
    then
        printf 'SEANDROIDENFORCE' >> "$OUT"
    else
        EXTRA_ARGS=""
        [ -f "$HERE/rsa4096_boot.pem" ] && EXTRA_ARGS=" --key $HERE/rsa4096_boot.pem --algorithm SHA256_RSA4096"
        python2 "$TMPDOWN/avb/avbtool" add_hash_footer --image "$OUT" --partition_name boot --partition_size $deviceinfo_bootimg_partition_size $EXTRA_ARGS

        if [ -n "$deviceinfo_bootimg_append_vbmeta" ] && $deviceinfo_bootimg_append_vbmeta; then
            python2 "$TMPDOWN/avb/avbtool" append_vbmeta_image --image "$OUT" --partition_size "$deviceinfo_bootimg_partition_size" --vbmeta_image "$TMPDOWN/vbmeta.img"
        fi
    fi
fi

if [ -n "$deviceinfo_has_recovery_partition" ] && $deviceinfo_has_recovery_partition; then
    RECOVERY="$(dirname "$OUT")/recovery.img"
    EXTRA_ARGS=""

    if [ "$deviceinfo_bootimg_header_version" -eq 2 ]; then
        EXTRA_ARGS+=" --header_version $deviceinfo_bootimg_header_version --dtb $DTB --dtb_offset $deviceinfo_flash_offset_dtb"
    fi

    if [ "$deviceinfo_bootimg_header_version" -eq 0 ] && [ -n "$DT" ]; then
        EXTRA_ARGS+=" --header_version $deviceinfo_bootimg_header_version --dt $DT"
    fi

    if [ -n "$DTBO" ]; then
        EXTRA_ARGS+=" --recovery_dtbo $DTBO"
    fi

    mkbootimg --kernel "$KERNEL" --ramdisk "$RECOVERY_RAMDISK" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize --cmdline "$deviceinfo_kernel_cmdline" -o "$RECOVERY" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS

    if [ -n "$deviceinfo_recovery_partition_size" ]; then
        EXTRA_ARGS=""
        if [ "$deviceinfo_bootimg_tailtype" == "SEAndroid" ]
        then
            printf 'SEANDROIDENFORCE' >> "$RECOVERY"
        else
            [ -f "$HERE/rsa4096_recovery.pem" ] && EXTRA_ARGS=" --key $HERE/rsa4096_recovery.pem --algorithm SHA256_RSA4096"
            python2 "$TMPDOWN/avb/avbtool" add_hash_footer --image "$RECOVERY" --partition_name recovery --partition_size $deviceinfo_recovery_partition_size $EXTRA_ARGS
        fi
    fi
fi
