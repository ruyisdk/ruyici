#!/bin/bash
# install dependency
yum install -y gcc git make glib2-devel.x86_64 ninja-build libcap-ng-devel.x86_64 libattr-devel.x86_64
yum install -y glib2-static.x86_64

git config --global --add safe.directory '*'
cd /home/src
git submodule update --init --recursive
mkdir build-static
cd build-static
../configure --target-list=riscv64-linux-user,riscv32-linux-user --prefix=/home/build/$1 --disable-werror --static
make -j $(nproc)
make install
cd ..
rm -r build-static
chmod -R 777 /home/src
chmod -R 777 /home/build
