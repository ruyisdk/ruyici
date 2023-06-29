#!/bin/bash

set -x

yum install -y cmake ninja-build autoconf automake python3 libmpc-devel mpfr-devel gmp-devel gawk bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel make diffutils
cd /home/build/$1
cmake -DLLVM_ENABLE_PROJECTS="clang" -DCMAKE_BUILD_TYPE="Release"  -G Ninja ../../src/llvm
ninja
