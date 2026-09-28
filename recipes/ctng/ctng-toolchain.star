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

# Per-host build characteristics. ``triplet`` is the Canadian-cross
# CT_HOST value (empty for native builds); ``suffix`` is the
# ``<os>-<arch>`` component of the result tarball name; ``container``
# selects between the containerized Linux path and the native macOS
# path.
_HOSTS = {
    "amd64": {"triplet": "", "suffix": "linux-amd64", "container": True},
    "arm64": {"triplet": "aarch64-linux-gnu", "suffix": "linux-arm64", "container": True},
    "riscv64": {"triplet": "riscv64-linux-gnu", "suffix": "linux-riscv64", "container": True},
    "macos-arm64": {"triplet": "", "suffix": "macos-arm64", "container": False},
}

# Linux hosts build in the unified container on the amd64 CI box and are
# always enabled; macOS builds must run on the Apple Silicon rig and are
# opt-in per recipe.
_DEFAULT_HOSTS = ["amd64", "arm64", "riscv64"]


def ctng_toolchain(data, hosts = None):
    """Return a ``{host: build_function}`` dict for a ct-ng toolchain.

    ``data`` is the TOML-dict loaded by the stub.  Expected keys:

    * ``artifacts.<host>.globs`` — list of artifact glob patterns
    * ``defconfig`` — relative path to the seed ``.defconfig.in`` file
      under the recipe project root (via ``ctx.repo_path``)
    * ``tarball_name`` (optional) — if present, result tarballs are
      named ``<tarball_name>-<datestamp>.<os>-<arch>.tar.*`` instead of
      the seed's pkgversion-derived name
    * ``datestamp`` (optional) — required iff ``tarball_name`` is set

    ``hosts`` defaults to the containerized Linux hosts
    (``["amd64", "arm64", "riscv64"]``); pass an explicit list to opt
    into additional hosts such as ``"macos-arm64"``.

    Recognized build parameters (``ruyi admin build-package -v``):

    * ``builder_tag`` — container image override (Linux hosts)
    * ``build_volume`` — case-sensitive build volume path (macOS hosts,
      default ``/Volumes/RuyiSDKBuild``)
    * ``ctng_debug`` — if set to a non-empty value other than ``"0"``,
      enable ``CT_DEBUG_CT`` and ``CT_DEBUG_CT_SAVE_STEPS``
    """
    if hosts == None:
        hosts = _DEFAULT_HOSTS

    defconfig_rel = data["defconfig"]
    tarball_name = data.get("tarball_name", "")
    datestamp = data.get("datestamp", "")
    if tarball_name and not datestamp:
        fail("ctng_toolchain: datestamp is required when tarball_name is set")

    builds = {}
    for h in hosts:
        if h not in _HOSTS:
            fail("ctng_toolchain: unknown host %r (known: %s)" % (h, ", ".join(sorted(_HOSTS))))
        spec = _HOSTS[h]
        globs = data["artifacts"][h]["globs"]

        def _make_build(_host = h, _spec = spec, _globs = globs):
            def build(ctx):
                builder_tag = ctx.var("builder_tag", default = "")
                return ctng_invocation(
                    ctx,
                    defconfig_path = ctx.repo_path(defconfig_rel),
                    artifact_globs = _globs,
                    host_triplet = _spec["triplet"],
                    host_suffix = _spec["suffix"],
                    tarball_name = tarball_name,
                    datestamp = datestamp,
                    builder_tag = builder_tag if builder_tag else None,
                    containerize = _spec["container"],
                    build_volume = ctx.var("build_volume", default = "/Volumes/RuyiSDKBuild"),
                    debug = ctx.var("ctng_debug", default = "") not in ("", "0"),
                )

            return build

        builds[h] = _make_build()

    return builds
