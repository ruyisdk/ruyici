#!/bin/bash
# this file is meant to be sourced

image_tag_pkgbuilder() {
    local kind="$1"
    local host_arch="$2"
    local tag

    case "$kind" in
    unified)
        tag="ghcr.io/ruyisdk/ruyi-ci-pkgbuilder-unified"
        case "$host_arch" in
        amd64)
            echo "$tag:20250918"
            ;;
        *)
            echo "error: image_tag_pkgbuilder: unsupported host arch $host_arch" >&2
            return 1
            ;;
        esac
        ;;

    rust-musl)
        tag="ghcr.io/ruyisdk/ruyi-ci-pkgbuilder-rust-musl"
        case "$host_arch" in
        amd64)
            echo "$tag:20250524"
            ;;
        *)
            echo "error: image_tag_pkgbuilder: unsupported host arch $host_arch" >&2
            return 1
            ;;
        esac
        ;;

    *)
        echo "error: image_tag_pkgbuilder: unsupported image kind $kind" >&2
        ;;
    esac
}
