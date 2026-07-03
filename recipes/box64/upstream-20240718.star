# box64 upstream 20240718 (v0.3.0 release)

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/box64/box64.star", "box64_build")

data = RUYI.load_toml(
    "ruyi-build-data://recipes/box64/upstream-20240718.toml",
)
for name, fn in box64_build(data).items():
    RUYI.build.schedule_build(fn, name = name)
