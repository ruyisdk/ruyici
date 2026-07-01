# Common backbone for versioned DynamoRIO build recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/dynamorio/dynamorio.star", "dynamorio_build")
#
#     data = RUYI.load_toml(
#         "ruyi-build-data://recipes/dynamorio/upstream-20240914.toml")
#     for name, fn in dynamorio_build(data).items():
#         RUYI.build.schedule_build(fn, name = name)
#
# ``dynamorio_build`` returns a ``{host: build_function}`` dict from the
# TOML data.  The stub is responsible for loading the data and scheduling
# the builds -- the backbone is a pure helper with no side effects.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "dynamorio_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]


def dynamorio_build(data, hosts = None):
    """Return a ``{host: build_function}`` dict for a DynamoRIO build.

    ``data`` is the TOML-dict loaded by the stub.  Expected keys
    match the ``dynamorio_invocation`` required config: ``P``, ``PV``,
    ``RUYI_DATESTAMP``, ``SRC_URI``, ``SRC_REF``.

    ``hosts`` defaults to ``["amd64", "arm64", "riscv64"]``.
    """
    if hosts == None:
        hosts = list(_HOSTS)

    builds = {}
    for h in hosts:
        def _make_build(_host = h):
            def build(ctx):
                builder_tag = ctx.var("builder_tag", default = "")
                return dynamorio_invocation(
                    ctx,
                    config = data,
                    arch = _host,
                    builder_tag = builder_tag if builder_tag else None,
                )

            return build

        builds[h] = _make_build()

    return builds
