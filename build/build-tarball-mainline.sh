#!/bin/bash
set -ex

device=$1
output=$(realpath "$2")
dir=$(realpath "$3")
# "normal", "usrmerge", "overlaystore"
mode=${4:-normal}

echo "Working on device: $device; mode: $mode"
if [ ! -f "$dir/partitions/boot.img" ]; then
    echo "boot.img does not exist!"
exit 1; fi

if [ "$mode" = "usrmerge" ]; then
    cd "$dir"
    # make sure udev rules and kernel modules are installed into /usr/lib
    # as /lib is symlink to /usr/lib on focal+
    # https://wiki.debian.org/UsrMerge
    if [ -d system/lib ]; then
        mkdir -p system/usr
        cp -a system/lib system/usr/ && rm -rf system/lib
    fi
elif [ "$mode" = "overlaystore" ]; then
    cd "$dir"
    # Expects everything under system/ to be configured properly for overlay store.
    # Use .opt to that * won't match it.
    mkdir -p system/.opt/halium-overlay/
    mv system/* system/.opt/halium-overlay/
    mv system/.opt system/opt
fi

output_name=device_"$device"
[ "$mode" = "usrmerge" ] && output_name=device_"$device"_usrmerge

tar -cJf "$output/$output_name.tar.xz" -C "$dir" \
    --owner=root --group=root \
    partitions/ system/
echo "$(date +%Y%m%d)-$RANDOM" > "$output/$output_name.tar.build"
