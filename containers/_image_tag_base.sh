#!/bin/bash
# this file is meant to be sourced

image_tag_pkgbuilder_unified() {
    local host_arch="$1"

    case "$host_arch" in
        amd64)
            echo "ghcr.io/ruyisdk/ruyi-ci-pkgbuilder-unified:20250401"
            ;;
        *)
            echo "error: image_tag_pkgbuilder_unified: unsupported host arch $host_arch" >&2
            return 1
            ;;
    esac
}
