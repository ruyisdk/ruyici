RUYI = ruyi_plugin_rev(1)

load("ruyi-build://recipes/wlink/wlink.star", "wlink_build")

data = RUYI.load_toml(
    "ruyi-build-data://recipes/wlink/upstream-20250524.toml",
)
for name, fn in wlink_build(data).items():
    RUYI.build.schedule_build(fn, name = name)
