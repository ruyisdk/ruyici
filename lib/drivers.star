# Per-driver Starlark helpers.
#
# Each ``*_invocation`` function encapsulates the mounts and inner-binary
# argv for one legacy ``ruyi-build-*`` outer script.
#
# Host paths are deliberately assembled from ``ctx.repo_root`` as plain
# strings (via ``repo_host_path``) rather than realpath-resolved through
# ``ctx.repo_path(...)``; this is important for directories such as
# ``work/`` which are commonly symlinked to a tmpfs. Paths that genuinely
# must live inside the project (the inner scripts and config files) are
# passed in already resolved by the recipe.

load("ruyi-build://lib/docker.star", "docker_run")
load("ruyi-build://lib/images.star", "pkgbuilder_image_tag")
load("ruyi-build://lib/paths.star", "repo_host_path")


def ctng_invocation(ctx, defconfig_path, artifact_globs, host_triplet = "", builder_tag = None):
    """Plan a ``ruyi-build-ctng-inner`` run for one defconfig.

    Mirrors the mount set of the legacy ``ruyi-build-ctng`` wrapper:
    ``out``, ``prefix``, ``src``, ``work`` (rw) and ``toolchain-patches``
    plus the inner script and the defconfig (ro).

    ``artifact_globs`` is a list of glob patterns (evaluated under the
    project's ``output_dir``) identifying the tarballs produced by this
    defconfig. Callers should pass a glob specific enough not to match
    unrelated artifacts from previous runs.

    If ``host_triplet`` is non-empty, the inner script appends
    ``CT_CANADIAN=y`` and ``CT_HOST="<triplet>"`` to the defconfig
    before invoking ct-ng, so that a single seed defconfig can serve
    both native (amd64) and cross (arm64, riscv64) builds.
    """

    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

    env = {}
    if host_triplet:
        env["CTNG_HOST_TRIPLET"] = host_triplet

    return ctx.subprocess(
        argv = docker_run(
            image = image,
            mounts_rw = [
                (repo_host_path(ctx, "out"), "/out"),
                (repo_host_path(ctx, "prefix"), "/opt/ruyi"),
                (repo_host_path(ctx, "src"), "/src"),
                (repo_host_path(ctx, "work"), "/work"),
            ],
            mounts_ro = [
                (repo_host_path(ctx, "toolchain-patches"), "/patches"),
                (
                    ctx.repo_path("ruyi-build-ctng-inner"),
                    "/usr/local/bin/ruyi-build-ctng-inner",
                ),
                (defconfig_path, "/tmp/seed.defconfig"),
            ],
            env = env,
            argv = ["ruyi-build-ctng-inner", "/tmp/seed.defconfig"],
        ),
        cwd = ctx.repo_root,
        produces = [ctx.artifact(glob = g) for g in artifact_globs],
    )


def qemu_invocation(
        ctx,
        config,
        arch,
        flavor,
        src_tarball = None,
        builder_tag = None):
    """Plan a ``ruyi-build-qemu-inner`` run.

    Mirrors the mount set of the legacy ``ruyi-build-qemu`` wrapper:
    ``out`` and ``work`` (rw), the inner script and the optional source
    tarball (ro), and ``/tmp/mem`` as a real tmpfs. Configuration that
    the legacy wrapper read from a sourced shell file is passed as
    environment variables instead; ``config`` is a dict of those
    variables and must carry at least:

    ``build_flavor``, ``P``, ``PV``, ``RUYI_DATESTAMP``, ``srcfile``,
    ``SRC_URI``, ``pkgversion``, ``USER_TARGETS``, ``SYSTEM_TARGETS``.

    Additional optional keys such as ``TAR_STRIP_COMPONENTS`` and
    ``USE_MEM`` may also be included and are passed through verbatim.

    Artifact globs are derived from ``arch`` and ``flavor``:

    * ``both`` or ``system`` -> ``qemu-system-riscv-<flavor>-*.<arch>.tar.zst``
    * ``both`` or ``user``   -> ``qemu-user-riscv-<flavor>-*.<arch>.tar.zst``
    """

    if flavor not in ("both", "system", "user"):
        fail("qemu_invocation: flavor must be one of both/system/user (got %r)" % flavor)

    _required = [
        "build_flavor",
        "P",
        "PV",
        "RUYI_DATESTAMP",
        "srcfile",
        "SRC_URI",
        "pkgversion",
        "USER_TARGETS",
        "SYSTEM_TARGETS",
    ]
    for k in _required:
        if k not in config:
            fail("qemu_invocation: config is missing required key %r" % k)

    build_flavor = config["build_flavor"]
    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

    mounts_ro = [
        (
            ctx.repo_path("ruyi-build-qemu-inner"),
            "/usr/local/bin/ruyi-build-qemu-inner",
        ),
    ]
    if src_tarball:
        mounts_ro.append((src_tarball, "/tmp/src.tar.xz"))

    produces = []
    if flavor in ("both", "system"):
        produces.append(ctx.artifact(
            glob = "qemu-system-riscv-%s-*.%s.tar.zst" % (build_flavor, arch),
        ))
    if flavor in ("both", "user"):
        produces.append(ctx.artifact(
            glob = "qemu-user-riscv-%s-*.%s.tar.zst" % (build_flavor, arch),
        ))

    return ctx.subprocess(
        argv = docker_run(
            image = image,
            mounts_rw = [
                (repo_host_path(ctx, "out"), "/out"),
                (repo_host_path(ctx, "work"), "/work"),
            ],
            mounts_ro = mounts_ro,
            tmpfs = ["/tmp/mem"],
            env = config,
            argv = [
                "ruyi-build-qemu-inner",
                "",
                arch,
                flavor,
            ],
        ),
        cwd = ctx.repo_root,
        produces = produces,
    )


def llvm_invocation(ctx, config, arch, src_tarball = None, builder_tag = None):
    """Plan a ``ruyi-build-llvm-inner`` run.

    Mirrors the mount set of the legacy ``ruyi-build-llvm`` wrapper:
    ``out`` and ``work`` (rw), the inner script and the optional source
    tarball (ro), and ``/tmp/mem`` as a real tmpfs. Configuration that
    the legacy wrapper read from a sourced shell file is passed as
    environment variables instead; ``config`` is a dict of those
    variables and must carry at least:

    ``P``, ``PV``, ``RUYI_DATESTAMP``, ``SRC_URI``.

    Additional optional keys such as ``TAR_STRIP_COMPONENTS``,
    ``LLVM_VENDOR``, ``CLANG_VENDOR``, ``CLANG_REPOSITORY_STRING``, and
    ``BUG_REPORT_URL`` may also be included and are passed through
    verbatim.

    Artifact glob is derived from ``arch``:

    ``{P}.ruyi-{RUYI_DATESTAMP}.{arch}.tar.zst``
    """

    if arch not in ("amd64", "arm64", "riscv64"):
        fail("llvm_invocation: arch must be one of amd64/arm64/riscv64 (got %r)" % arch)

    _required = [
        "P",
        "PV",
        "RUYI_DATESTAMP",
        "SRC_URI",
    ]
    for k in _required:
        if k not in config:
            fail("llvm_invocation: config is missing required key %r" % k)

    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

    mounts_ro = [
        (
            ctx.repo_path("ruyi-build-llvm-inner"),
            "/usr/local/bin/ruyi-build-llvm-inner",
        ),
    ]
    if src_tarball:
        mounts_ro.append((src_tarball, "/tmp/src.tar.xz"))

    artifact_glob = "%s.ruyi-%s.%s.tar.zst" % (
        config["P"],
        config["RUYI_DATESTAMP"],
        arch,
    )

    return ctx.subprocess(
        argv = docker_run(
            image = image,
            mounts_rw = [
                (repo_host_path(ctx, "out"), "/out"),
                (repo_host_path(ctx, "work"), "/work"),
            ],
            mounts_ro = mounts_ro,
            tmpfs = ["/tmp/mem"],
            env = config,
            argv = [
                "ruyi-build-llvm-inner",
                "",
                arch,
            ],
        ),
        cwd = ctx.repo_root,
        produces = [ctx.artifact(glob = artifact_glob)],
    )
