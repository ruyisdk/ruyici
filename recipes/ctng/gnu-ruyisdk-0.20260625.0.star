# toolchain: gnu-ruyisdk 0.20260625.0

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/ctng/ctng-toolchain.star", "ctng_toolchain")

data = RUYI.load_toml(
    "ruyi-build-data://recipes/ctng/gnu-ruyisdk-0.20260625.0.toml",
)
for name, fn in ctng_toolchain(
    data,
    hosts = ["amd64", "arm64", "riscv64", "darwin-aarch64"],
).items():
    RUYI.build.schedule_build(fn, name = name)
