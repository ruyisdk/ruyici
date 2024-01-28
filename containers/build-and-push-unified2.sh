#!/bin/bash

set -e

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$MY_DIR"
source ./_image_tag_base.sh

cd "unified2"
exec docker buildx build --rm \
    --platform "linux/amd64" \
    -t "$(image_tag_pkgbuilder_unified amd64)" \
    --push \
    .
