# toolchain: gnu-ruyisdk 0.20260625.0

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/ctng/ctng-toolchain.star", "ctng_toolchain")

ctng_toolchain(RUYI, "gnu-ruyisdk-0.20260625.0")
