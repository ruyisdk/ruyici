# syntax=docker/dockerfile:1

FROM --platform=linux/amd64 rust:1.87-alpine3.21

RUN <<DOCKEREOF
apk add --no-cache bash curl git musl-dev

rustup target add aarch64-unknown-linux-musl
rustup target add riscv64gc-unknown-linux-musl
# rustup target add x86_64-unknown-linux-musl  # this is preinstalled

cd /opt
wget -O - https://musl.cc/aarch64-linux-musl-cross.tgz | tar x -z -f -
wget -O - https://musl.cc/riscv64-linux-musl-cross.tgz | tar x -z -f -

mkdir -p ~/.cargo
cat > ~/.cargo/config.toml <<EOF
[target.aarch64-unknown-linux-musl]
linker = "/opt/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc"
[target.riscv64gc-unknown-linux-musl]
linker = "/opt/riscv64-linux-musl-cross/bin/riscv64-linux-musl-gcc"
EOF

DOCKEREOF

ENV RUSTFLAGS="-C target-feature=+crt-static"
ENV CC_aarch64_unknown_linux_musl=/opt/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc
ENV CC_riscv64gc_unknown_linux_musl=/opt/riscv64-linux-musl-cross/bin/riscv64-linux-musl-gcc
