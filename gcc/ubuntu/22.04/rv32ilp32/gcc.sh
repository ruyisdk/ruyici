#!/bin/bash

set -x

apt-get update
apt-get install -y autoconf automake autotools-dev curl python3 python3-pip libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build git cmake libglib2.0-dev
cd /home/src
./configure --prefix=/home/build/$1 --with-arch=rv32imac --with-abi=ilp32
make linux -j $(nproc)
