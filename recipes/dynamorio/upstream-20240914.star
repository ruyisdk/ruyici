# DynamoRIO upstream 20240914

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/dynamorio/dynamorio.star", "dynamorio_build")

dynamorio_build(RUYI, "upstream-20240914")
