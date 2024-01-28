#!/bin/bash

set -e

export CC=clang
export CXX=clang++
export CFLAGS="-O2 -pipe -fPIC"
export CXXFLAGS="$CFLAGS"

MAKEOPTS=(
    -j "$(nproc)"
)

python3 -m venv /tmp/meson-venv
. /tmp/meson-venv/bin/activate
pip install meson packaging

cat > /tmp/meson.amd64.ini <<EOF
[binaries]
c = 'clang'
cpp = 'clang++'

[properties]
c_args = ['-O2', '-pipe', '-fPIC']
cpp_args = ['-O2', '-pipe', '-fPIC']
EOF

cat > /tmp/meson.arm64.ini <<EOF
[binaries]
c = ['clang', '--target=aarch64-linux-gnu']
cpp = ['clang++', '--target=aarch64-linux-gnu']
c_ld = 'lld'
cpp_ld = 'lld'

[properties]
c_args = ['-O2', '-pipe', '-fPIC']
cpp_args = ['-O2', '-pipe', '-fPIC']

[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF

cat > /tmp/meson.riscv64.ini <<EOF
[binaries]
c = ['clang', '--target=riscv64-linux-gnu']
cpp = ['clang++', '--target=riscv64-linux-gnu']
c_ld = 'lld'
cpp_ld = 'lld'

[properties]
c_args = ['-O2', '-pipe', '-fPIC']
cpp_args = ['-O2', '-pipe', '-fPIC']

[host_machine]
system = 'linux'
cpu_family = 'riscv64'
cpu = 'riscv64'
endian = 'little'
EOF

INSTALL_ROOT_AMD64=/opt/morelibs/amd64
INSTALL_ROOT_ARM64=/opt/morelibs/arm64
INSTALL_ROOT_RISCV64=/opt/morelibs/riscv64

mkdir -p "$INSTALL_ROOT_AMD64"
mkdir -p "$INSTALL_ROOT_ARM64"
mkdir -p "$INSTALL_ROOT_RISCV64"

# for LLVM's PIC code to be able to link to these
# the distro -dev package apparently isn't PIC

ZLIB_NG_PV=2.1.4
ZLIB_NG_SRC_URI="https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIB_NG_PV}.tar.gz"

NCURSES_PV=6.4
NCURSES_SRC_URI="https://invisible-mirror.net/archives/ncurses/ncurses-6.4.tar.gz"

GLIB_PV=2.79.1
GLIB_SRC_URI="https://download.gnome.org/sources/glib/2.79/glib-2.79.1.tar.xz"

pushd /tmp
    wget -O "zlib-ng-${ZLIB_NG_PV}.tar.gz" "$ZLIB_NG_SRC_URI"
    wget "$NCURSES_SRC_URI"
    wget "$GLIB_SRC_URI"
    tar xf "zlib-ng-${ZLIB_NG_PV}.tar.gz"
    tar xf "ncurses-${NCURSES_PV}.tar.gz"
    tar xf "glib-${GLIB_PV}.tar.xz"
popd

#
# zlib-ng as replacement for zlib
#

ZLIB_NG_SRC_DIR="/tmp/zlib-ng-$ZLIB_NG_PV"
ZLIB_NG_COMMON_CMAKE_ARGS=(
    -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_C_COMPILER="$CC"
    -DCMAKE_CXX_COMPILER="$CXX"
    -DZLIB_COMPAT=ON
    -DZLIB_ENABLE_TESTS=OFF
    -DWITH_GTEST=OFF
)

mkdir /tmp/zlib-ng-build.amd64
pushd /tmp/zlib-ng-build.amd64
    cmake "$ZLIB_NG_SRC_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT_AMD64" \
        -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
        "${ZLIB_NG_COMMON_CMAKE_ARGS[@]}"
    ninja
    ninja install
popd

mkdir /tmp/zlib-ng-build.arm64
pushd /tmp/zlib-ng-build.arm64
    cmake "$ZLIB_NG_SRC_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT_ARM64" \
        -DCMAKE_C_FLAGS="--target=aarch64-linux-gnu $CFLAGS" \
        -DCMAKE_CXX_FLAGS="--target=aarch64-linux-gnu $CXXFLAGS" \
        "${ZLIB_NG_COMMON_CMAKE_ARGS[@]}"
    ninja
    ninja install
popd

mkdir /tmp/zlib-ng-build.riscv64
pushd /tmp/zlib-ng-build.riscv64
    cmake "$ZLIB_NG_SRC_DIR" \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_ROOT_ARM64" \
        -DCMAKE_C_FLAGS="--target=riscv64-linux-gnu $CFLAGS -fuse-ld=lld" \
        -DCMAKE_CXX_FLAGS="--target=riscv64-linux-gnu $CXXFLAGS -fuse-ld=lld" \
        "${ZLIB_NG_COMMON_CMAKE_ARGS[@]}"
    ninja
    ninja install
popd

rm -rf /tmp/zlib-ng-build.*

#
# ncurses
#

NCURSES_SRC_DIR="/tmp/ncurses-$NCURSES_PV"
NCURSES_COMMON_CONF_ARGS=(
    --without-manpages
    --without-progs
    --without-tack
    --without-tests
    --with-termlib
    --enable-widec
    --disable-termcap
    --disable-term-driver
    --enable-const
    --enable-ext-colors
    --enable-colorfgbg
    # apparently this is not necessary; llvm does its own locking
    # see llvm/lib/Support/Unix/Process.inc
    #--with-pthread
    #--enable-reentrant
)

mkdir /tmp/ncurses-build.amd64
pushd /tmp/ncurses-build.amd64
    "$NCURSES_SRC_DIR"/configure \
        --host=x86_64-pc-linux-gnu \
        --prefix="$INSTALL_ROOT_AMD64" \
        "${NCURSES_COMMON_CONF_ARGS[@]}"
    make "${MAKEOPTS[@]}"
    make install "${MAKEOPTS[@]}"
popd

mkdir /tmp/ncurses-build.arm64
pushd /tmp/ncurses-build.arm64
    "$NCURSES_SRC_DIR"/configure \
        --host=aarch64-linux-gnu \
        --prefix="$INSTALL_ROOT_ARM64" \
        "${NCURSES_COMMON_CONF_ARGS[@]}"
    make "${MAKEOPTS[@]}"
    make install "${MAKEOPTS[@]}"
popd

mkdir /tmp/ncurses-build.riscv64
pushd /tmp/ncurses-build.riscv64
    "$NCURSES_SRC_DIR"/configure \
        --host=riscv64-linux-gnu \
        --prefix="$INSTALL_ROOT_RISCV64" \
        "${NCURSES_COMMON_CONF_ARGS[@]}"
    make "${MAKEOPTS[@]}"
    make install "${MAKEOPTS[@]}"
popd

rm -rf /tmp/ncurses-build.*

#
# glib
#

GLIB_SRC_DIR="/tmp/glib-$GLIB_PV"
mkdir /tmp/glib-build.{amd64,arm64,riscv64}

GLIB_COMMON_CONF_ARGS=(
    -Ddocumentation=false
)

pushd "$GLIB_SRC_DIR"
    # source preparation taken from Gentoo
    sed -i -e '/subdir.*tests/d' {.,gio,glib}/meson.build
    sed -i -e '/subdir.*fuzzing/d' meson.build

    # configure
    meson setup /tmp/glib-build.amd64 --native-file /tmp/meson.amd64.ini \
        --prefix "$INSTALL_ROOT_AMD64" \
        "${GLIB_COMMON_CONF_ARGS[@]}"
    meson setup /tmp/glib-build.arm64 --cross-file /tmp/meson.arm64.ini \
        --prefix "$INSTALL_ROOT_ARM64" \
        "${GLIB_COMMON_CONF_ARGS[@]}"
    meson setup /tmp/glib-build.riscv64 --cross-file /tmp/meson.riscv64.ini \
        --prefix "$INSTALL_ROOT_RISCV64" \
        "${GLIB_COMMON_CONF_ARGS[@]}"
popd

pushd /tmp/glib-build.amd64
    ninja
    ninja install
popd

pushd /tmp/glib-build.arm64
    ninja
    ninja install
popd

# TODO: fails to build bundled libffi due to seemingly missing definition for
# max_align_t (which should not happen)
#pushd /tmp/glib-build.riscv64
#    ninja
#    ninja install
#popd

rm -rf /tmp/glib-build.*
