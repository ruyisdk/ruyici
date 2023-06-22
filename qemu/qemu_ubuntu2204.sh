#!/bin/bash
# install dependency
apt install gcc git make ninja-build python3 python3-pip libglib2.0-dev libpixman-1-dev libslirp-dev
# apt build-dep qemu

cd /home/src
mkdir build
cd build
../configure --target-list=riscv64-softmmu,riscv64-linux-user,riscv32-softmmu,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --enable-virtfs --enable-slirp
make -j $(nproc)
make install
