#!/bin/bash

set -e

cd "$(dirname "${BASH_SOURCE[0]}")"/..
find . \
    -name out -prune \
    -o -name prefix -prune \
    -o -name '*-configs' -prune \
    -o \( -name '*.sh' -print0 \) | xargs -0 shellcheck -P . -P scripts
