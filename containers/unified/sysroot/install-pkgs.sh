#!/bin/bash

set -e

ARCH="$1"
# $BUILDARCH is populated by the builder
# $LLVM_MAJOR is defined in the Dockerfile

[[ $BUILDARCH == "$ARCH" ]] && IS_NATIVE=true || IS_NATIVE=false

echo "ARCH: $ARCH"
echo "BUILDARCH: $BUILDARCH"

# Much of the following are taken from the ct-ng test suite:
# https://github.com/crosstool-ng/crosstool-ng/blob/cf6b1740a14634406bb3426309dd92af8faa06fb/testing/docker/ubuntu22.04/Dockerfile

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

# deps needed in every sysroot
pkgs=(
    build-essential
    # for ct-ng
    libncurses5-dev libzstd-dev
    # for LLVM
    libedit-dev libffi-dev libjsoncpp-dev libz3-dev liblzma-dev
)

# and additionally for the native arch
if "$IS_NATIVE"; then
    pkgs+=(
        # for ct-ng
        gcc g++ gperf bison flex texinfo help2man make
        python3-dev autoconf automake libtool libtool-bin gawk bzip2 xz-utils unzip
        patch libstdc++6 rsync git meson ninja-build

        # for targetting aarch64 host
        crossbuild-essential-arm64

        # for targetting riscv64 host
        crossbuild-essential-riscv64

        # for ruyi-build driver
        schedtool

        # common goodies
        zstd clang-"$LLVM_MAJOR" lld-"$LLVM_MAJOR"

        # for LLVM
        cmake pkgconf

        # for QEMU
        python3-venv

        # for DynamoRIO
        python3.11-dev python3.11-venv

        # useful debugging tools etc.
        ccache vim strace
    )
fi

# for QEMU
# several deps are not installable from alt arches (e.g. gcc-cross pkgs)
# so we have to specify the individual deps ourselves
# the list is taken from https://salsa.debian.org/qemu-team/qemu/-/blob/master/debian/control-in
pkgs+=(
    libglib2.0-dev
    zlib1g-dev
    libaio-dev
    libjack-dev
    libpulse-dev
    libasound2-dev
    libpipewire-0.3-dev
    libbpf-dev
    libcap-ng-dev
    libcurl4-gnutls-dev
    libfdt-dev
    libfuse3-dev
    gnutls-dev
    libgtk-3-dev
    libvte-2.91-dev
    libiscsi-dev
    libncurses-dev
    libvirglrenderer-dev
    libepoxy-dev
    libdrm-dev
    libgbm-dev
    libnfs-dev
    libnuma-dev
    libpixman-1-dev
    libsasl2-dev
    libsdl2-dev
    libseccomp-dev
    libslirp-dev
    libspice-server-dev
    liburing-dev
    libusb-1.0-0-dev
    libusbredirparser-dev
    libssh-dev
    # libzstd-dev  # already unconditionally included
    nettle-dev
    libudev-dev
    libjpeg-dev
    libpng-dev
)

# for DynamoRIO
# see https://dynamorio.org/page_building.html
pkgs+=(
    # zlib1g-dev  # already unconditionally included for qemu
    libsnappy-dev
    liblz4-dev
    libunwind-dev
)

apt-get install -y "${pkgs[@]}"

if "$IS_NATIVE"; then
    # symlink LLVM tools
    pushd /usr/local/bin
        ln -s /usr/bin/clang-"$LLVM_MAJOR" clang
        ln -s /usr/bin/clang++-"$LLVM_MAJOR" clang++
        ln -s /usr/bin/ld.lld-"$LLVM_MAJOR" ld.lld
    popd
fi

make_pkg_config_wrapper() {
    local host="$1"

    # similar to the wrapper script in Ubuntu 20.04
    cat > /usr/bin/"${host}-pkg-config" <<EOF
#!/bin/bash
[[ -n \$PKG_CONFIG_LIBDIR ]] && exec pkg-config "\$@"

PKG_CONFIG_LIBDIR="/usr/local/${host}/lib/pkgconfig"
# For a native build we would also want to append /usr/local/lib/pkgconfig
# at this point; but this is a cross-building script, so don't
PKG_CONFIG_LIBDIR="\$PKG_CONFIG_LIBDIR:/usr/local/share/pkgconfig"
PKG_CONFIG_LIBDIR="/usr/local/lib/${host}/pkgconfig:\$PKG_CONFIG_LIBDIR"
PKG_CONFIG_LIBDIR="\$PKG_CONFIG_LIBDIR:/usr/lib/${host}/pkgconfig"
PKG_CONFIG_LIBDIR="\$PKG_CONFIG_LIBDIR:/usr/${host}/lib/pkgconfig"
PKG_CONFIG_LIBDIR="\$PKG_CONFIG_LIBDIR:/usr/share/pkgconfig"
export PKG_CONFIG_LIBDIR
exec pkg-config "\$@"
EOF

    chmod a+x /usr/bin/"${host}-pkg-config"
}

# make pkg-config wrappers
# pkg-config-${CHOST} has been removed since Ubuntu 22.04
for chost in aarch64-linux-gnu riscv64-linux-gnu; do
    make_pkg_config_wrapper "$chost"
done
