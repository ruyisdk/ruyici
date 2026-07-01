# DynamoRIO upstream 20240914

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/dynamorio/dynamorio.star", "dynamorio_build")

data = RUYI.load_toml(
    "ruyi-build-data://recipes/dynamorio/upstream-20240914.toml",
)
for name, fn in dynamorio_build(data).items():
    RUYI.build.schedule_build(fn, name = name)
