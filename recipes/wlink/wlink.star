# Common backbone for versioned wlink build recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/wlink/wlink.star", "wlink_build")
#
#     data = RUYI.load_toml(
#         "ruyi-build-data://recipes/wlink/upstream-20250524.toml")
#     for name, fn in wlink_build(data).items():
#         RUYI.build.schedule_build(fn, name = name)
#
# ``wlink_build`` returns a ``{arch: build_function}`` dict from the
# TOML data.  The stub is responsible for loading the data and scheduling
# the builds -- the backbone is a pure helper with no side effects.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "wlink_invocation")

_HOSTS = ["aarch64", "riscv64", "x86_64"]


def wlink_build(data, hosts = None):
    """Return a ``{arch: build_function}`` dict for a wlink build.

    ``data`` is the TOML-dict loaded by the stub.  Expected keys
    match the ``wlink_invocation`` required config: ``P``, ``PV``,
    ``RUYI_DATESTAMP``, ``SRC_URI``, ``SRC_REF``.

    ``hosts`` defaults to aarch64, riscv64 and x86_64.
    """
    if hosts == None:
        hosts = list(_HOSTS)

    builds = {}
    for h in hosts:
        def _make_build(_host = h):
            def build(ctx):
                builder_tag = ctx.var("builder_tag", default = "")
                return wlink_invocation(
                    ctx,
                    config = data,
                    arch = _host,
                    builder_tag = builder_tag if builder_tag else None,
                )

            return build

        builds[h] = _make_build()

    return builds
