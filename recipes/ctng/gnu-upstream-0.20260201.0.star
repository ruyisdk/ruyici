# toolchain: gnu-upstream 0.20260201.0

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/ctng/ctng-toolchain.star", "ctng_toolchain")

ctng_toolchain("gnu-upstream-0.20260201.0")
