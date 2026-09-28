# Common backbone for versioned box64 build recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/box64/box64.star", "box64_build")
#
#     data = RUYI.load_toml(
#         "ruyi-build-data://recipes/box64/upstream-20240718.toml")
#     for name, fn in box64_build(data).items():
#         RUYI.build.schedule_build(fn, name = name)
#
# ``box64_build`` returns a ``{host: build_function}`` dict from the
# TOML data.  The stub is responsible for loading the data and scheduling
# the builds -- the backbone is a pure helper with no side effects.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "box64_invocation")

_HOSTS = ["aarch64", "riscv64"]


def box64_build(data, hosts = None):
    """Return a ``{host: build_function}`` dict for a box64 build.

    ``data`` is the TOML-dict loaded by the stub.  Expected keys
    match the ``box64_invocation`` required config: ``P``, ``PV``,
    ``RUYI_DATESTAMP``, ``SRC_URI``.  ``TAR_STRIP_COMPONENTS`` and
    ``USE_MEM`` are optional.

    ``hosts`` defaults to aarch64 and riscv64 (x86_64 is rejected).
    """
    if hosts == None:
        hosts = list(_HOSTS)

    builds = {}
    for h in hosts:
        def _make_build(_host = h):
            def build(ctx):
                builder_tag = ctx.var("builder_tag", default = "")
                src_tarball = ctx.var("src", default = "")
                return box64_invocation(
                    ctx,
                    config = data,
                    arch = _host,
                    src_tarball = src_tarball if src_tarball else None,
                    builder_tag = builder_tag if builder_tag else None,
                )

            return build

        builds[h] = _make_build()

    return builds
