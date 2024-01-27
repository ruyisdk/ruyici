#!/bin/bash

set -e

# Much of the following are taken from the ct-ng test suite:
# https://github.com/crosstool-ng/crosstool-ng/blob/cf6b1740a14634406bb3426309dd92af8faa06fb/testing/docker/ubuntu22.04/Dockerfile

groupadd -g "$BUILDER_GID" b
useradd -d /home/b -m -g "$BUILDER_GID" -u "$BUILDER_UID" -s /bin/bash b

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# HTTPS needs ca-certificates to work
# sed -i 's@http://archive\.ubuntu\.com/@http://mirrors.huaweicloud.com/@g' /etc/apt/sources.list
# Also enable the cross arches for installing libraries via apt
cat > /etc/apt/sources.list <<EOF
deb [arch=amd64] http://mirrors.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
deb [arch=amd64] http://mirrors.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
deb [arch=amd64] http://mirrors.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
deb [arch=amd64] http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse

deb-src http://mirrors.huaweicloud.com/ubuntu/ focal main restricted universe multiverse
deb-src http://mirrors.huaweicloud.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src http://mirrors.huaweicloud.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse

deb [arch=arm64,riscv64] http://mirrors.huaweicloud.com/ubuntu-ports/ focal main restricted universe multiverse
deb [arch=arm64,riscv64] http://mirrors.huaweicloud.com/ubuntu-ports/ focal-updates main restricted universe multiverse
deb [arch=arm64,riscv64] http://mirrors.huaweicloud.com/ubuntu-ports/ focal-backports main restricted universe multiverse
deb [arch=arm64,riscv64] http://mirrors.huaweicloud.com/ubuntu-ports/ focal-security main restricted universe multiverse
EOF

# For `apt build-dep`
#sed -i 's/^# deb-src/deb-src/' /etc/apt/sources.list

# Non-interactive configuration of tzdata
debconf-set-selections <<EOF
tzdata tzdata/Areas select Etc
tzdata tzdata/Zones/Etc select UTC
EOF

apt-get update

# Install recent cmake
apt-get install -y wget software-properties-common lsb-release ca-certificates
wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"

# And recent LLVM
wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc
apt-add-repository "deb http://apt.llvm.org/focal/ llvm-toolchain-focal-17 main"

apt-get update

dpkg --add-architecture arm64
dpkg --add-architecture riscv64

pkgs=(
    # for ct-ng
    gcc g++ gperf bison flex texinfo help2man make libncurses5-dev
    python3-dev autoconf automake libtool libtool-bin gawk bzip2 xz-utils unzip
    patch libstdc++6 rsync git meson ninja-build

    # for targetting riscv64 host
    crossbuild-essential-riscv64
    pkg-config-riscv64-linux-gnu

    # for targetting aarch64 host
    crossbuild-essential-arm64
    pkg-config-aarch64-linux-gnu

    # for ruyi-build driver
    schedtool

    # common goodies
    zstd clang-17 lld-17
    libzstd-dev

    # for LLVM
    build-essential cmake pkgconf
    libedit-dev libffi-dev libjsoncpp-dev libz3-dev liblzma-dev

    # for QEMU
    python3-venv

    # TODO
    # libzstd-dev:arm64 libzstd-dev:riscv64
    # libedit-dev:arm64 libffi-dev:arm64 libjsoncpp-dev:arm64 libz3-dev:arm64 liblzma-dev:arm64
    # libedit-dev:riscv64 libffi-dev:riscv64 libjsoncpp-dev:riscv64 libz3-dev:riscv64 liblzma-dev:riscv64
)

apt-get upgrade -qqy
apt-get install -y "${pkgs[@]}"

# for QEMU
apt-get build-dep -y qemu
# TODO
# apt-get build-dep -y -a arm64 qemu
# apt-get build-dep -y -a riscv64 qemu

apt-get clean
