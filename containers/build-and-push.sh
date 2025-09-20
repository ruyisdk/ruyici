#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND="${1:?usage: $0 <image kind>}"
ARCH=amd64

cd "$MY_DIR"
# shellcheck source-path=SCRIPTDIR
source ./_image_tag_base.sh

tag="$(image_tag_pkgbuilder "$KIND" "$ARCH")"
if [[ -z $tag ]]; then
    echo "$0: cannot determine image to build" >&2
    exit 1
fi

cd "$KIND"
exec docker buildx build --rm \
    --platform "linux/$ARCH" \
    -t "$tag" \
    --push \
    .
