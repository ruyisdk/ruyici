# Common backbone for versioned ct-ng toolchain recipes.
#
# Usage from a thin stub:
#
#     RUYI = ruyi_plugin_rev(1)
#     load("ruyi-build://recipes/ctng/ctng-toolchain.star", "ctng_toolchain")
#     ctng_toolchain(RUYI, "gnu-upstream-0.20260201.0")
#
# By convention the function loads ``<name>.toml`` for artifact globs
# and mounts ``<name>.defconfig.in`` as the seed defconfig. Host-specific
# lines (CT_CANADIAN, CT_HOST) are appended by the inner script when
# the host is not the native amd64 builder.

load("ruyi-build://lib/drivers.star", "ctng_invocation")

_HOST_TRIPLETS = {
    "amd64": "",
    "arm64": "aarch64-linux-gnu",
    "riscv64": "riscv64-linux-gnu",
}


def ctng_toolchain(ruyi, name, hosts = None):
    """Register one scheduled build per host for a ct-ng toolchain.

    ``ruyi`` is the caller's ``RUYI`` object (so that builds are
    registered under the caller's recipe file, not the backbone).

    ``name`` is the base filename (without extension) shared by the
    three convention-driven files:

    * ``<name>.toml`` — TOML with ``[artifacts.<host>].globs``
    * ``<name>.defconfig.in`` — seed defconfig (no host-specific lines)
    * ``<name>.star`` — the thin stub recipe that calls us

    ``hosts`` defaults to ``["amd64", "arm64", "riscv64"]``.
    """
    if hosts == None:
        hosts = sorted(_HOST_TRIPLETS)

    data = ruyi.load_toml(
        "ruyi-build-data://recipes/ctng/%s.toml" % name,
    )
    defconfig_rel = "recipes/ctng/%s.defconfig.in" % name

    def _make_build(host):
        triplet = _HOST_TRIPLETS[host]
        globs = data["artifacts"][host]["globs"]

        def build(ctx):
            builder_tag = ctx.var("builder_tag", default = "")
            return ctng_invocation(
                ctx,
                defconfig_path = ctx.repo_path(defconfig_rel),
                artifact_globs = globs,
                host_triplet = triplet,
                builder_tag = builder_tag if builder_tag else None,
            )

        return build

    for h in hosts:
        ruyi.build.schedule_build(_make_build(h), name = h)
