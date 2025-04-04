# syntax=docker/dockerfile:1

# build cross sysroots
FROM --platform=linux/arm64 ubuntu:22.04 AS sysroot-arm64
ARG BUILDARCH
COPY --link ./sysroot/prepare-distro.sh /image/prepare-distro.sh
RUN /image/prepare-distro.sh arm64
COPY --link ./sysroot/install-pkgs.sh /image/install-pkgs.sh
RUN /image/install-pkgs.sh arm64

FROM --platform=linux/riscv64 ubuntu:22.04 AS sysroot-riscv64
ARG BUILDARCH
COPY --link ./sysroot/prepare-distro.sh /image/prepare-distro.sh
RUN /image/prepare-distro.sh riscv64
COPY --link ./sysroot/install-pkgs.sh /image/install-pkgs.sh
RUN /image/install-pkgs.sh riscv64

# assemble the final builder image (also the amd64 sysroot)
FROM --platform=linux/amd64 ubuntu:22.04
ARG BUILDARCH
ARG BUILDER_UID=1000
ARG BUILDER_GID=1000
ARG CT_NG_GIT_BUILD=true
ARG CT_NG_GIT_BRANCH=master
ARG CT_NG_GIT_REPO=https://github.com/crosstool-ng/crosstool-ng.git
# ARG CT_NG_VERSION=1.26.0
# ARG CT_NG_DOWNLOAD_URL_BASE="http://crosstool-ng.org/download/crosstool-ng"
ARG LLVM_MAJOR=20

COPY --link ./sysroot/prepare-distro.sh /image/prepare-distro.sh
RUN /image/prepare-distro.sh amd64
COPY --link ./sysroot/install-pkgs.sh /image/install-pkgs.sh
RUN /image/install-pkgs.sh amd64

COPY --link ./builder/fix-multilib.patch /image/ct-ng-patches/fix-multilib.patch
COPY --link ./builder/install-ct-ng.sh /image/install-ct-ng.sh
RUN /image/install-ct-ng.sh

COPY --from=sysroot-arm64 --link / /sysroot/arm64
COPY --from=sysroot-riscv64 --link / /sysroot/riscv64

RUN groupadd -g "$BUILDER_GID" b && useradd -d /home/b -m -g "$BUILDER_GID" -u "$BUILDER_UID" -s /bin/bash b
USER $BUILDER_UID:$BUILDER_GID
WORKDIR /home/b
