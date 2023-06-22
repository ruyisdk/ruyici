#!/bin/bash
# install dependency
apt update
apt install -y gcc git make ninja-build python3 python3-pip libglib2.0-dev libpixman-1-dev
# apt build-dep qemu

cd /home/src
mkdir build-static
cd build-static
../configure --target-list=riscv64-linux-user,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --static
make -j $(nproc)
make install
