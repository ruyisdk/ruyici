#!/bin/bash

set -x

yum update
yum install -y autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel make diffutils
cd /home/src
./configure --prefix=/home/build/$1 --with-arch=rv64gc_zba_zbb_zbc_zbs
make linux -j $(nproc)
