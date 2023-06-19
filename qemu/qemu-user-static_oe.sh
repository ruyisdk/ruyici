#!/bin/bash
# install dependency
yum install gcc git make glib2-devel.x86_64 ninja-build libcap-ng-devel.x86_64 libattr-devel.x86_64
yum install glib2-static.x86_64

cd /home/src
mkdir build-static
cd build-static
../configure --target-list=riscv64-linux-user,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --static
make -j $(nproc)
make install
