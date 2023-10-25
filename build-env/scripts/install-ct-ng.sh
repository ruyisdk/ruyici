#!/bin/bash

set -e

CT_NG_FILENAME="crosstool-ng-${CT_NG_VERSION}.tar.xz"

cd /tmp
wget "${CT_NG_DOWNLOAD_URL_BASE}/${CT_NG_FILENAME}"
# TODO: signature verification

mkdir ct-ng-tmp
pushd ct-ng-tmp
tar -xf "/tmp/${CT_NG_FILENAME}" --strip-components=1
./configure --prefix=/usr/local
make -j4
make install
popd

rm -rf ct-ng-tmp
