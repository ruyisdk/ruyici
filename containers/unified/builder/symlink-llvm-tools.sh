#!/bin/sh

set -e

# $LLVM_MAJOR is defined in the Dockerfile
cd /usr/local/bin
ln -s /usr/bin/clang-"$LLVM_MAJOR" clang
ln -s /usr/bin/clang++-"$LLVM_MAJOR" clang++
ln -s /usr/bin/ld.lld-"$LLVM_MAJOR" ld.lld
