FROM ubuntu:22.04

ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
ARG CT_NG_VERSION=1.26.0
ARG CT_NG_DOWNLOAD_URL_BASE="http://crosstool-ng.org/download/crosstool-ng"

COPY ./scripts/prepare-distro.sh /tmp/prepare-distro.sh
RUN /tmp/prepare-distro.sh

COPY ./scripts/install-ct-ng.sh /tmp/install-ct-ng.sh
RUN /tmp/install-ct-ng.sh
