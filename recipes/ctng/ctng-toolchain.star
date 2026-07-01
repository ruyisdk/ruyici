# Common backbone for versioned ct-ng toolchain recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/ctng/ctng-toolchain.star", "ctng_toolchain")
#
#     data = RUYI.load_toml(
#         "ruyi-build-data://recipes/ctng/gnu-upstream-0.20260201.0.toml")
#     for name, fn in ctng_toolchain(data).items():
#         RUYI.build.schedule_build(fn, name = name)
#
# ``ctng_toolchain`` returns a ``{host: build_function}`` dict from the
# TOML data.  The stub is responsible for loading the data and scheduling
# the builds -- the backbone is a pure helper with no side effects.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "ctng_invocation")

_HOST_TRIPLETS = {
    "amd64": "",
    "arm64": "aarch64-linux-gnu",
    "riscv64": "riscv64-linux-gnu",
}


def ctng_toolchain(data, hosts = None):
    """Return a ``{host: build_function}`` dict for a ct-ng toolchain.

    ``data`` is the TOML-dict loaded by the stub.  Expected keys:

    * ``artifacts.<host>.globs`` — list of artifact glob patterns
    * ``defconfig`` — relative path to the seed ``.defconfig.in`` file
      under the recipe project root (via ``ctx.repo_path``)

    ``hosts`` defaults to ``["amd64", "arm64", "riscv64"]``.
    """
    if hosts == None:
        hosts = sorted(_HOST_TRIPLETS)

    defconfig_rel = data["defconfig"]

    builds = {}
    for h in hosts:
        triplet = _HOST_TRIPLETS[h]
        globs = data["artifacts"][h]["globs"]

        def _make_build(_host = h, _triplet = triplet, _globs = globs):
            def build(ctx):
                builder_tag = ctx.var("builder_tag", default = "")
                return ctng_invocation(
                    ctx,
                    defconfig_path = ctx.repo_path(defconfig_rel),
                    artifact_globs = _globs,
                    host_triplet = _triplet,
                    builder_tag = builder_tag if builder_tag else None,
                )

            return build

        builds[h] = _make_build()

    return builds
