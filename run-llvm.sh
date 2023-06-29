#!/bin/bash

git clone https://github.com/llvm/llvm-project.git --depth 1 --branch release/15.x
cd llvm-project
docker pull openeuler/openeuler:23.03
docker run -itd --restart=always -v  $PWD:/home/llvm-project --name llvm-chunyu openeuler/openeuler:23.03 /bin/bash
docker exec llvm-chunyu /bin/sh -c "dnf install -y cmake ninja-build autoconf automake make python3 libmpc-devel mpfr-devel gmp-devel gawk  bison flex texinfo patchutils gcc gcc-c++ zlib-devel expat-devel diffutils &&
cd /home/llvm-project && mkdir rvoe23_03_llvm && cd rvoe23_03_llvm &&
cmake -DLLVM_ENABLE_PROJECTS="clang" -DCMAKE_BUILD_TYPE="Release"  -G Ninja ../llvm &&
ninja &&
cd ../ &&
tar -czvf rvoe23_03_llvm.tar.gz rvoe23_03_llvm/;"
cp rvoe23_03_llvm.tar.gz ../
docker exec llvm-chunyu /bin/sh -c " cd /home/llvm-project && rm -rf rvoe23_03_llvm rvoe23_03_llvm.tar.gz"
#rm -rf ../llvm-project
docker stop llvm-chunyu && docker rm llvm-chunyu
