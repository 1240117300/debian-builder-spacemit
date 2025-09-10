#!/bin/bash

#
# SPDX-License-Identifier: Apache-2.0
#
# Debian 13 (trixie) gnome desktop build script for SpacemiT RISC-V
#
# Features:
#   1. Bootstrap Debian RISC-V root filesystem
#   2. Install GNOME desktop and common packages
#   3. Generate rootfs.ext4, bootfs.ext4, Titan and SDCard images
#
# Usage:
#   sudo ./debian-image-create.sh
#   or sudo ./debian-image-create.sh minimal
#   or sudo ./debian-image-create.sh desktop
# Requirements:
#   - debootstrap, qemu-user-static, wget, tar, genimage, zip, python3
#

set -e

TARGET_ROOTFS=./debian-13-rootfs-desktop-k1
HOST_NAME=k1
DEBIAN_MIRROR=http://deb.debian.org/debian
MINBASE_TAR=debian-13-rootfs-desktop-k1.tar.gz
# Get current date and time as version number
CURRENT_DATETIME=$(date +%Y%m%d%H%M)
FIRMWARE_NAME="debian-13"
CONFIG_DIR=./config

# Parameter processing
if [ $# -eq 0 ]; then
    # No parameters: build both firmware types
    FIRMWARE_TYPE="all"
    MIRROR=""
elif [ $# -eq 1 ]; then
    # One parameter: firmware type
    FIRMWARE_TYPE="$1"
    MIRROR=""
elif [ $# -eq 2 ]; then
    # Two parameters: firmware type and mirror
    FIRMWARE_TYPE="$1"
    MIRROR="$2"
fi


inf() { echo -e "\033[;34mInfo: $*\033[0m"; }
err() { echo -e "\033[;31mError: $*\033[0m" >&2; exit 1; }

# Check and install necessary dependencies
check_and_install_dependencies() {
    inf "=== Checking system dependencies ==="

    # Check debootstrap
    if ! command -v debootstrap >/dev/null 2>&1; then
        apt-get -y install debootstrap
    fi

    # Check qemu-riscv64-static

    if [ ! -f "rvv" ]; then
        wget http://archive.spacemit.com/qemu/rvv
        chmod a+x rvv
    fi

    # Test execution
    if ./rvv 2>&1 | grep -q "helloworld"; then
        inf "qemu-user-static check passed"
    fi

}

mount_filesystem() {
    inf "Mounting pseudo filesystems into $1"
    mount | grep "$1/proc" >/dev/null || mount -t proc /proc $1/proc
    mount | grep "$1/sys" >/dev/null || mount -t sysfs /sys $1/sys
    mount | grep "$1/dev" >/dev/null || mount -o bind /dev $1/dev
    mount | grep "$1/dev/pts" >/dev/null || mount -o bind /dev/pts $1/dev/pts
}

umount_filesystem() {
    inf "Unmounting pseudo filesystems from $1"
    mount | grep "$1/proc" >/dev/null 2>&1 && umount -l $1/proc || true
    mount | grep "$1/sys" >/dev/null 2>&1 && umount -l $1/sys || true
    mount | grep "$1/dev/pts" >/dev/null 2>&1 && umount -l $1/dev/pts || true
    mount | grep "$1/dev" >/dev/null 2>&1 && umount -l $1/dev || true
}

clean_build() {
    inf "=== Cleaning old artifacts ==="
    umount_filesystem $TARGET_ROOTFS
    find . -maxdepth 1 ! -name '.' ! -name "$MINBASE_TAR" ! -name "$(basename $0)" ! -name "config" ! -name "*.zip" ! -name "*.img.zip" -exec rm -rf {} +
}

check_and_extract_minbase() {
    if [ -f "$MINBASE_TAR" ]; then
        inf "=== Found minbase archive, extracting directly ==="
        rm -rf $TARGET_ROOTFS
        mkdir -p $TARGET_ROOTFS
        tar -xzf "$MINBASE_TAR" -C "$TARGET_ROOTFS"
        return 0
    fi
    return 1
}

package_minbase_rootfs_tar() {
    inf "=== Packaging minbase root filesystem ==="
    umount_filesystem $TARGET_ROOTFS
    tar -czf "$MINBASE_TAR" -C "$TARGET_ROOTFS" .
    inf " Generated $MINBASE_TAR"
}

# Create minbase rootfs via debootstrap and perform initial setup
make_minbase_rootfs() {
    inf "=== Creating debian13 trixie minbase root filesystem ==="
    mkdir -p $TARGET_ROOTFS

    if [ -n "$MIRROR" ]; then
        debootstrap --arch=riscv64 --variant=minbase trixie $TARGET_ROOTFS "http://$MIRROR/debian"
    else
        debootstrap --arch=riscv64 --variant=minbase trixie $TARGET_ROOTFS $DEBIAN_MIRROR
    fi

    mount_filesystem $TARGET_ROOTFS

    echo "$HOST_NAME" > $TARGET_ROOTFS/etc/hostname

    cat > $TARGET_ROOTFS/etc/hosts <<EOF
127.0.0.1 localhost
127.0.0.1 $HOST_NAME
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

    chroot $TARGET_ROOTFS /bin/bash -c 'echo "nameserver 10.0.26.16" >/etc/resolv.conf'
    chroot $TARGET_ROOTFS /bin/bash -c 'echo "nameserver 10.0.26.17" >>/etc/resolv.conf'

    if [ -n "$MIRROR" ]; then
        chroot $TARGET_ROOTFS /bin/bash -c "sed -i 's|http://deb.debian.org|http://$MIRROR|g' /etc/apt/sources.list"
    else
        cat > $TARGET_ROOTFS/etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian trixie main non-free-firmware
deb http://deb.debian.org/debian trixie-updates main non-free-firmware
EOF
    fi

    chroot $TARGET_ROOTFS /bin/bash -c "apt-get update"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install ca-certificates wget gpg"
    chroot $TARGET_ROOTFS /bin/bash -c "wget -O- http://archive.spacemit.com/bianbu/bianbu-archive-keyring.gpg | gpg --dearmor | tee /usr/share/keyrings/bianbu-archive-keyring.gpg > /dev/null"
    chroot $TARGET_ROOTFS /bin/bash -c "cp /usr/share/keyrings/bianbu-archive-keyring.gpg /etc/apt/trusted.gpg.d/"

    # bianbu repository
    cat > $TARGET_ROOTFS/etc/apt/sources.list.d/bianbu.sources <<EOF
Types: deb deb-src
URIs: http://archive.spacemit.com/debian/
Suites: trixie
Components: main
Signed-By: /usr/share/keyrings/bianbu-archive-keyring.gpg
EOF

    # apt priority
    cat > $TARGET_ROOTFS/etc/apt/preferences.d/bianbu <<EOF
Package: *
Pin: release o=Spacemit, n=trixie
Pin-Priority: 1100
EOF

    # initramfs
    chroot $TARGET_ROOTFS /bin/bash -c "apt-get update"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y --allow-downgrades upgrade"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install initramfs-tools fdisk e2fsprogs"

    # bootloader and bianbu software
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install u-boot-spacemit opensbi-spacemit bianbu-esos linux-generic linux-tools-6.6.63"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install img-gpu-powervr k1x-vpu-firmware k1x-cam spacemit-uart-bt spacemit-modules-usrload spacemit-flash-dtbs"

    cp $CONFIG_DIR/bianbu.bmp $TARGET_ROOTFS/boot/bianbu.bmp
}

install_desktop() {
    inf "=== Installing GNOME desktop ==="
    chroot $TARGET_ROOTFS /bin/bash -c '
    echo "keyboard-configuration  keyboard-configuration/xkb-model select pc105" | debconf-set-selections
    echo "keyboard-configuration  keyboard-configuration/modelcode string pc105" | debconf-set-selections
    echo "keyboard-configuration  keyboard-configuration/layoutcode string us" | debconf-set-selections
    echo "keyboard-configuration  keyboard-configuration/variantcode string" | debconf-set-selections
    echo "keyboard-configuration  keyboard-configuration/optionscode string" | debconf-set-selections
    echo "keyboard-configuration  keyboard-configuration/backspace select guess" | debconf-set-selections
    '
    chroot $TARGET_ROOTFS /bin/bash -c "apt-get update"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install tasksel whiptail"
    chroot $TARGET_ROOTFS /bin/bash -c "tasksel install desktop gnome-desktop"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive systemctl set-default graphical.target"
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install gnome-initial-setup"

    # Install mesa
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install libegl1-mesa libglapi-mesa libgbm1 libgbm-dev libegl-mesa0 libgl1-mesa-dri libgles2-mesa libgl1-mesa-glx libglx-mesa0 libosmesa6 libwayland-egl1-mesa mesa-common-dev mesa-vdpau-drivers mesa-vulkan-drivers"

    # Boot animation
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install plymouth-themes && plymouth-set-default-theme spinner && update-initramfs -u"

}

install_common_packages() {
    local firmware_type="$1"

    if [ "$firmware_type" = "minimal" ]; then
        chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install  systemd systemd-sysv vim iproute2 dbus"
    else
        chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install chromium-browser-stable mpp vim ssh iproute2 v4l-utils"
    fi
}

apply_common_config() {
    local firmware_type="$1"
    inf "=== Common configuration ==="
    inf "reconfiguring locales"

    if [ "$firmware_type" = "minimal" ]; then
        chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install locales"
    else
        chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get -y install locales task-chinese-s task-chinese-s-desktop"
    fi
    chroot $TARGET_ROOTFS /bin/bash -c "echo 'locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8, zh_CN.UTF-8 UTF-8' | debconf-set-selections"
    chroot $TARGET_ROOTFS /bin/bash -c "echo 'locales locales/default_environment_locale select zh_CN.UTF-8' | debconf-set-selections"
    chroot $TARGET_ROOTFS /bin/bash -c "sed -i 's/^# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen"
    chroot $TARGET_ROOTFS /bin/bash -c "dpkg-reconfigure --frontend=noninteractive locales"

    inf "reconfiguring tzdata"
    chroot $TARGET_ROOTFS /bin/bash -c "echo 'tzdata tzdata/Areas select Asia' | debconf-set-selections"
    chroot $TARGET_ROOTFS /bin/bash -c "echo 'tzdata tzdata/Zones/Asia select Shanghai' | debconf-set-selections"
    chroot $TARGET_ROOTFS /bin/bash -c "rm -f -v /etc/timezone"
    chroot $TARGET_ROOTFS /bin/bash -c "rm /etc/localtime"
    chroot $TARGET_ROOTFS /bin/bash -c "dpkg-reconfigure --frontend=noninteractive tzdata"

    inf "changing root password"
    chroot $TARGET_ROOTFS /bin/bash -c "echo root:bianbu | chpasswd"

    # Time server
    sed -i 's/^#NTP=.*/NTP=ntp.aliyun.com/' $TARGET_ROOTFS/etc/systemd/timesyncd.conf

    # Restore DNS
    chroot $TARGET_ROOTFS /bin/bash -c 'echo "nameserver 127.0.0.53" > /etc/resolv.conf'

}

generate_ext4_images() {
    local firmware_type="$1"
    inf "Generating ext4 images"

    UUID_BOOTFS=$(uuidgen)
    UUID_ROOTFS=$(uuidgen)
    cat > $TARGET_ROOTFS/etc/fstab <<EOF
UUID=$UUID_ROOTFS   /        ext4    defaults,noatime,errors=remount-ro 0 1
UUID=$UUID_BOOTFS   /boot    ext4    defaults                           0 2
EOF

    mkdir -p bootfs
    mv $TARGET_ROOTFS/boot/* bootfs

    mke2fs -d bootfs -L bootfs -t ext4 -U $UUID_BOOTFS bootfs.ext4 256M
    if [ "$firmware_type" = "minimal" ]; then
        mke2fs -d $TARGET_ROOTFS -L rootfs -t ext4 -N 524288 -U $UUID_ROOTFS rootfs.ext4 2048M
    else
        mke2fs -d $TARGET_ROOTFS -L rootfs -t ext4 -N 524288 -U $UUID_ROOTFS rootfs.ext4 8192M
    fi

    e2fsck -f -y bootfs.ext4
    e2fsck -f -y rootfs.ext4

    inf "Images generated: bootfs.ext4 + rootfs.ext4"
}

# Install dependencies
install_dependencies() {
    local image_type="$1"
    if [ "$image_type" = "titan" ]; then
        if ! command -v zip >/dev/null 2>&1; then
            apt-get -y install zip
        fi
    elif [ "$image_type" = "sdcard" ]; then
        local need_install=""
        command -v wget >/dev/null 2>&1 || need_install="${need_install} wget"
        command -v python3 >/dev/null 2>&1 || need_install="${need_install} python3"
        command -v genimage >/dev/null 2>&1 || need_install="${need_install} genimage"
        if [ -n "$need_install" ]; then
            DEBIAN_FRONTEND=noninteractive apt-get -y install $need_install
        fi
    fi
}

# Prepare common files (execute only once)
prepare_common_files() {
    export TMP=pack_dir
    mkdir -p $TMP/factory/

    # Copy related files
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/bootinfo_emmc.bin $TMP/factory
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/bootinfo_sd.bin $TMP/factory
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/bootinfo_spinand.bin $TMP/factory
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/bootinfo_spinor.bin $TMP/factory
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/FSBL.bin $TMP/factory
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/u-boot.itb $TMP
    cp $TARGET_ROOTFS/usr/lib/u-boot/spacemit/env.bin $TMP
    cp $TARGET_ROOTFS/usr/lib/riscv64-linux-gnu/opensbi/generic/fw_dynamic.itb $TMP
    cp bootfs.ext4 $TMP
    cp rootfs.ext4 $TMP

    # get common partition table
    # wget -P $TMP https://gitee.com/bianbu/image-config/raw/main/partition_universal.json
    cp $CONFIG_DIR/partition_universal.json $TMP
}

make_titan_image() {
    inf "Creating Titan image"

    # Install dependencies
    install_dependencies "titan"

    # get Titan-specific partition table files
    # wget -P $TMP https://gitee.com/bianbu/image-config/raw/main/fastboot.yaml
    # wget -P $TMP https://gitee.com/bianbu/image-config/raw/main/partition_2M.json
    # wget -P $TMP https://gitee.com/bianbu/image-config/raw/main/partition_flash.json
    cp $CONFIG_DIR/fastboot.yaml $TMP
    cp $CONFIG_DIR/partition_2M.json $TMP
    cp $CONFIG_DIR/partition_flash.json $TMP

    # Package
    pushd $TMP >/dev/null
    zip -r ../$FIRMWARE_NAME.zip *
    popd >/dev/null || return
    inf "Titan image generated: $FIRMWARE_NAME.zip"
}

make_sdcard_image() {
    inf "=== Creating SDCard image ==="

    # Install dependencies
    install_dependencies "sdcard"

    # get and generate genimage.cfg
    #wget -P $TMP https://gitee.com/bianbu-linux/scripts/raw/bl-v1.0.y/gen_imgcfg.py
    cp $CONFIG_DIR/gen_imgcfg.py $TMP
    python3 $TMP/gen_imgcfg.py -i $TMP/partition_universal.json -n sdcard.img -o $TMP/genimage.cfg

    # Generate SDCard image
    ROOTPATH_TMP="$(mktemp -d)"
    GENIMAGE_TMP="$(mktemp -d)"
    genimage \
        --config "$TMP/genimage.cfg" \
        --rootpath "$ROOTPATH_TMP" \
        --tmppath "$GENIMAGE_TMP" \
        --inputpath "$TMP" \
        --outputpath "."

    mv sdcard.img $TMP.img
    zip $FIRMWARE_NAME.img.zip $TMP.img
    # Delete temporary directories and files generated during .img.zip creation
    rm -rf $ROOTPATH_TMP $GENIMAGE_TMP $TMP.img

    inf "SDCard image generated: $FIRMWARE_NAME.img.zip"
}

make_image() {
    # Prepare common files
    prepare_common_files

    # Create two types of images
    make_titan_image
    make_sdcard_image
}

main() {
   local build_type="$FIRMWARE_TYPE"  # Default to build all if no argument provided

    # Must be executed with sudo
    if [ "$EUID" -ne 0 ]; then
        err "Please execute this script with sudo!"
    fi

    # Check and install system dependencies
    check_and_install_dependencies

    case "$build_type" in
        "minimal")
            inf "=== Building minimal firmware only ==="
            build_minimal_firmware
            ;;
        "desktop")
            inf "=== Building desktop firmware only ==="
            build_desktop_firmware
            ;;
        "all")
            inf "=== Building both minimal and desktop firmware ==="
            build_minimal_firmware
            build_desktop_firmware
            ;;
        *)
            err "Invalid argument. Use: minimal, desktop, or no argument for both"
            ;;
    esac

    inf "Build finished successfully."
}

build_firmware() {
    local firmware_type="$1"
    local current_firmware_name="${FIRMWARE_NAME}-${firmware_type}-k1-${CURRENT_DATETIME}"

    inf "=== Building ${firmware_type} firmware ==="
    inf "Firmware name: ${current_firmware_name}"

    clean_build

    if ! check_and_extract_minbase; then
        make_minbase_rootfs
        package_minbase_rootfs_tar
    fi

    mount_filesystem $TARGET_ROOTFS

    # Install packages based on firmware type
    if [ "$firmware_type" = "desktop" ]; then
        install_desktop
    fi

    # Install common packages for both types
    install_common_packages "$firmware_type"

    apply_common_config "$firmware_type"

    # Cleanup
    chroot $TARGET_ROOTFS /bin/bash -c "DEBIAN_FRONTEND=noninteractive apt-get clean"

    umount_filesystem $TARGET_ROOTFS

    generate_ext4_images "$firmware_type"

    local original_firmware_name="$FIRMWARE_NAME"
    FIRMWARE_NAME="$current_firmware_name"

    make_image

    FIRMWARE_NAME="$original_firmware_name"

    inf "${firmware_type^} firmware build completed: ${current_firmware_name}"
}

build_minimal_firmware() {
    build_firmware "minimal"
}

build_desktop_firmware() {
    build_firmware "desktop"
}

main_minimal() {
    # Deprecated function, use main with "minimal" argument instead
    main "minimal"
}

main_desktop() {
    # Deprecated function, use main with "desktop" argument instead
    main "desktop"
}

main "$@"
