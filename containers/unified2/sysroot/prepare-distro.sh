#!/bin/bash

set -e

ARCH="$1"
# $BUILDARCH is populated by the builder
# $LLVM_MAJOR is defined in the Dockerfile

[[ $BUILDARCH == $ARCH ]] && IS_NATIVE=true || IS_NATIVE=false

echo "ARCH: $ARCH"
echo "BUILDARCH: $BUILDARCH"

case "$ARCH" in
amd64)
    #MIRROR="http://mirrors.huaweicloud.com/ubuntu/"
    MIRROR="http://mirrors.tuna.tsinghua.edu.cn/ubuntu/"
    ;;
*)
    # the huaweicloud mirror has dep problems with even build-essential
    #MIRROR="http://mirrors.huaweicloud.com/ubuntu-ports/"
    MIRROR="http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/"
    ;;
esac

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

source /etc/lsb-release
# $DISTRIB_CODENAME is the codename to use

# HTTPS needs ca-certificates to work
# sed -i 's@http://archive\.ubuntu\.com/@http://mirrors.huaweicloud.com/@g' /etc/apt/sources.list
# Also enable the cross arches for installing libraries via apt
cat > /etc/apt/sources.list <<EOF
deb $MIRROR $DISTRIB_CODENAME main restricted universe multiverse
deb $MIRROR $DISTRIB_CODENAME-updates main restricted universe multiverse
deb $MIRROR $DISTRIB_CODENAME-backports main restricted universe multiverse
deb $MIRROR $DISTRIB_CODENAME-security main restricted universe multiverse

deb-src $MIRROR $DISTRIB_CODENAME main restricted universe multiverse
deb-src $MIRROR $DISTRIB_CODENAME-updates main restricted universe multiverse
deb-src $MIRROR $DISTRIB_CODENAME-backports main restricted universe multiverse
deb-src $MIRROR $DISTRIB_CODENAME-security main restricted universe multiverse
EOF

# Non-interactive configuration of tzdata
debconf-set-selections <<EOF
tzdata tzdata/Areas select Etc
tzdata tzdata/Zones/Etc select UTC
EOF

apt-get update -q

if "$IS_NATIVE"; then
    # Pull in recent cmake
    apt-get install -qqy wget software-properties-common ca-certificates
    wget -qO- https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg > /dev/null
    apt-add-repository "deb https://apt.kitware.com/ubuntu/ $DISTRIB_CODENAME main"

    # And recent LLVM
    wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc > /dev/null
    apt-add-repository "deb http://apt.llvm.org/${DISTRIB_CODENAME}/ llvm-toolchain-${DISTRIB_CODENAME}-${LLVM_MAJOR} main"
fi

apt-get upgrade -qqy
