[中文](./README_CN.md)

# Introduction
This project provides a one-click script to build SpacemiT K1 Debian 13 images that are ready to use out of the box. Currently supports building GNOME, XFCE and Minimal images.

# GNOME Image


https://github.com/user-attachments/assets/53808a85-537f-4502-a669-539c963ae0e9


## Features
- Pre-installed native GNOME desktop with GPU support
- Pre-installed Chromium browser with hardware video decoding support
- Pre-installed common toolkits: vim, ssh, iproute2, wget
- Pre-configured [SpacemiT K1 Debian software sources](http://archive.spacemit.com/debian/)
- Wi-Fi and Ethernet support

## Features Not Yet Adapted
- FFmpeg and GStreamer frameworks
- Video applications
- Camera applications
- Serial Bluetooth, such as rtl8852bs

# XFCE Image


https://github.com/user-attachments/assets/74c713ce-ddd6-481e-bc52-27d0fdc78ed1


## Features
- Pre-installed native XFCE desktop (GPU is not supported yet)
- Pre-installed Chromium browser with hardware video decoding support
- Pre-installed common toolkits: vim, ssh, iproute2, wget
- Pre-configured [SpacemiT K1 Debian software sources](http://archive.spacemit.com/debian/)
- Wi-Fi and Ethernet support

## Features Not Yet Adapted
- FFmpeg and GStreamer frameworks
- Video applications
- Camera applications
- Serial Bluetooth, such as rtl8852bs

# Supported Hardware
- MUSE Pi pro
- MUSE Book
- BPI-F3
- Milk-V Jupiter (Not Tested)
- LicheePi 3A (Not Tested)

# Image Download
- Official: [Link](https://archive.spacemit.com/image/k1/version/debian/)
- Baidu Cloud: [Link](https://pan.baidu.com/s/1nbe5FYEtilqTcBHfFoM-Nw?pwd=vezm) (Extraction code: vezm)
- Google Drive: [Link](https://drive.google.com/drive/folders/143Ii9l68V9_X_Ryny84wsqLKmpDQ9LnX?usp=sharing)

# Flashing
- SD Card Raw Image

  Files ending with *.img.zip can be written to SD card using [balenaEtcher](https://etcher.balena.io/), or extracted and written using the dd command.

- Custom Image

  Files ending with .zip can be flashed using Titan Flasher, or extracted and flashed using fastboot.

Firmware `root` user password: `bianbu`

XFCE image initial username: user, password: `bianbu`

For Titan Flasher flashing, please refer to the [Flashing Tool User Manual](https://developer.spacemit.com/documentation?token=O6wlwlXcoiBZUikVNh2cczhin5d).

# Creating Your Own Image
If you want to create your own image, you can customize it following the steps below.

## Environment Preparation
You need an X86 PC, preferably running Ubuntu LTS version, such as Ubuntu 24.04.

## Installing Dependencies
Image creation requires qemu installation. Please install our recommended version by referring to the [qemu installation guide](https://bianbu.spacemit.com/system_integration/bianbu_3.0_rootfs_create/#qemu).

## Image Creation
You can run the following command to create all three images simultaneously:
```bash
sudo ./debian-image-create.sh
```
You can also specify parameters:

- Minimal
```bash
sudo ./debian-image-create.sh minimal
```

- GNOME
```bash
sudo ./debian-image-create.sh desktop
```

- XFCE
```bash
sudo ./debian-image-create.sh xfce
```

# Issue Reporting
Your feedback drives our iterations. Please submit issue reports in Issues, including the development board model, reproduction steps, and logs.

# Contributing
We welcome developers to contribute code and documentation.

To maximize the chances of your pull request being accepted, please follow these guidelines:

1. Write unit tests for all bug fixes and new features. If your code doesn't have tests, it won't be merged.
2. Minimize the number of changes in each pull request. Try to solve one problem at a time.
3. Use [conventional commit messages](https://www.conventionalcommits.org/en/v1.0.0/) as pull request titles. Examples:
   - New feature: `feat: adding foo API`
   - Bug fix: `fix: issue with foo API`
   - Documentation change: `docs: adding foo API documentation`

# TODO
