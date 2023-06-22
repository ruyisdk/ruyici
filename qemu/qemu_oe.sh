#!/bin/bash
# install dependency
yum install -y gcc git make glib2-devel.x86_64 ninja-build libcap-ng-devel.x86_64 libattr-devel.x86_64 libslirp-devel.x86_64

cd /home/src
mkdir build
cd build
../configure --target-list=riscv64-softmmu,riscv64-linux-user,riscv32-softmmu,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --enable-virtfs --enable-slirp
make -j $(nproc)
make install
