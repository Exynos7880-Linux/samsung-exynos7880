# Ubuntu Touch device tree for Samsung Exynos7880



## How to build

```
cp deviceinfo-a*y17lte deviceinfo # chage * to device you build for
./build.sh -b bd  # bd is the name of the build directory
./build/prepare-fake-ota.sh out/device_a5y17lte.tar.xz ota # for a5
./build/prepare-fake-ota.sh out/device_a7y17lte.tar.xz ota # for a7
./build/system-image-from-ota.sh ota/ubuntu_command out
```
