# Common backbone for versioned DynamoRIO build recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/dynamorio/dynamorio.star", "dynamorio_build")
#     dynamorio_build(RUYI, "upstream-20240914")
#
# By convention the function loads ``<name>.toml`` for build metadata
# (version, source URL, artifact prefix) and registers one scheduled
# build per supported host architecture.

load("ruyi-build://lib/drivers.star", "dynamorio_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]


def dynamorio_build(ruyi, name, hosts = None):
    """Register one scheduled build per host for a DynamoRIO build.

    ``ruyi`` is the caller's ``RUYI`` object (so that builds are
    registered under the caller's recipe file, not the backbone).

    ``name`` is the base name of the TOML data file under the
    convention ``recipes/dynamorio/<name>.toml``.

    ``hosts`` defaults to ``["amd64", "arm64", "riscv64"]``.
    """
    if hosts == None:
        hosts = list(_HOSTS)

    data = ruyi.load_toml(
        "ruyi-build-data://recipes/dynamorio/%s.toml" % name,
    )

    def _make_build(host):
        def build(ctx):
            builder_tag = ctx.var("builder_tag", default = "")
            return dynamorio_invocation(
                ctx,
                config = data,
                arch = host,
                builder_tag = builder_tag if builder_tag else None,
            )

        return build

    for h in hosts:
        ruyi.build.schedule_build(_make_build(h), name = h)
