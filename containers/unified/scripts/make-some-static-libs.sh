#!/bin/bash

set -e

export CC=clang
export CXX=clang++
export CFLAGS="-O2 -pipe -fPIC"
export CXXFLAGS="$CFLAGS"

MAKEOPTS=(
    -j "$(nproc)"
)

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

NCURSES_PV=6.3
NCURSES_SRC_URI="https://invisible-island.net/datafiles/release/ncurses.tar.gz"

pushd /tmp
    wget -O "zlib-ng-${ZLIB_NG_PV}.tar.gz" "$ZLIB_NG_SRC_URI"
    wget "$NCURSES_SRC_URI"
    tar xf "zlib-ng-${ZLIB_NG_PV}.tar.gz"
    tar xf ncurses.tar.gz
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
