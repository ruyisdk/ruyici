#!/bin/sh

set -e

cd /usr/bin
ln -s clang-17 clang
ln -s clang++-17 clang++
ln -s ld.lld-17 ld.lld
