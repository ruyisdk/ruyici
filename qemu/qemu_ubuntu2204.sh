#!/bin/bash
# install dependency
apt update
apt install -y gcc git make ninja-build python3 python3-pip libglib2.0-dev libpixman-1-dev libslirp-dev
# apt build-dep qemu

git config --global --add safe.directory '*'
cd /home/src
git submodule update --init --recursive
mkdir build
cd build
../configure --target-list=riscv64-softmmu,riscv64-linux-user,riscv32-softmmu,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --enable-virtfs --enable-slirp
make -j $(nproc)
make install
cd ..
rm -r build

