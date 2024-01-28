#!/bin/sh

set -e

# $LLVM_MAJOR is defined in the Dockerfile
cd /usr/bin
ln -s clang-"$LLVM_MAJOR" clang
ln -s clang++-"$LLVM_MAJOR" clang++
ln -s ld.lld-"$LLVM_MAJOR" ld.lld
