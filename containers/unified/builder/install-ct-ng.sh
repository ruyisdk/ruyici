#!/bin/bash

set -e

: "${CT_NG_GIT_BUILD:=false}"

if "$CT_NG_GIT_BUILD"; then
    : "${CT_NG_GIT_REPO:=https://github.com/crosstool-ng/crosstool-ng.git}"
    : "${CT_NG_GIT_BRANCH:=master}"
else
    : "${CT_NG_DOWNLOAD_URL_BASE:?CT_NG_DOWNLOAD_URL_BASE must be set for non-git builds}"
    : "${CT_NG_VERSION:?CT_NG_VERSION must be set for non-git builds}"
    CT_NG_FILENAME="crosstool-ng-${CT_NG_VERSION}.tar.xz"
fi

CT_NG_PATCH_DIR=/image/ct-ng-patches
CT_NG_CHECKOUT=/tmp/ct-ng-tmp

fetch() {
    if "$CT_NG_GIT_BUILD"; then
        local git_clone_options=(
            --depth 1
            --recurse-submodules
            --shallow-submodules
            -b "$CT_NG_GIT_BRANCH"
        )
        git clone "${git_clone_options[@]}" "$CT_NG_GIT_REPO" "$CT_NG_CHECKOUT"
    else
        wget "${CT_NG_DOWNLOAD_URL_BASE}/${CT_NG_FILENAME}"
        # TODO: signature verification
        mkdir -p "$CT_NG_CHECKOUT"
        pushd "$CT_NG_CHECKOUT" > /dev/null
        tar -xf "/tmp/$CT_NG_FILENAME" --strip-components=1
        popd > /dev/null
    fi
}

prepare() {
    pushd "$CT_NG_CHECKOUT" > /dev/null

    if [[ -d $CT_NG_PATCH_DIR ]]; then
        for p in "$CT_NG_PATCH_DIR"/*.patch; do
            echo "Applying $p..."
            patch -Np1 < "$p"
        done
    fi

    "$CT_NG_GIT_BUILD" && ./bootstrap

    popd > /dev/null
}

build_and_install() {
    pushd "$CT_NG_CHECKOUT" > /dev/null
    ./configure --prefix=/usr/local
    make -j4
    make install
    popd > /dev/null
}

clean() {
    rm -rf "$CT_NG_CHECKOUT"
    set +e
    [[ -n "$CT_NG_FILENAME" ]] && rm "/tmp/$CT_NG_FILENAME"
    set -e
}

main() {
    cd /tmp
    fetch
    prepare
    build_and_install
    clean
}

main
