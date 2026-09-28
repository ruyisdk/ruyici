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


def ctng_invocation(
        ctx,
        defconfig_path,
        artifact_globs,
        host_triplet = "",
        host_suffix = "",
        tarball_name = "",
        datestamp = "",
        builder_tag = None,
        containerize = True,
        build_volume = "",
        debug = False):
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

    If ``tarball_name`` is non-empty, the inner script overrides
    ``CT_TARBALL_RESULT_FILENAME`` so the result tarball is named
    ``<tarball_name>-<datestamp>.<host_suffix>.tar.*`` instead of the
    seed's pkgversion-derived name. ``datestamp`` and ``host_suffix``
    (e.g. ``"linux-x86_64"``, ``"darwin-aarch64"``) are required in that
    case.

    If ``containerize`` is false, the build runs directly on the host
    via the ``ruyi-build-ctng-inner-darwin`` script instead of docker;
    ``build_volume`` (a case-sensitive volume hosting the heavy working
    directories) is required in that case, and ``builder_tag`` is
    ignored. The result tarballs still land in the project's
    ``output_dir``.

    If ``debug`` is true, ``CT_DEBUG_CT`` and ``CT_DEBUG_CT_SAVE_STEPS``
    are appended to the rendered defconfig.
    """

    env = {}
    if host_triplet:
        env["CTNG_HOST_TRIPLET"] = host_triplet
    if tarball_name:
        if not datestamp or not host_suffix:
            fail(
                "ctng_invocation: datestamp and host_suffix are required "
                + "when tarball_name is set",
            )
        env["CTNG_TARBALL_NAME"] = tarball_name
        env["CTNG_DATESTAMP"] = datestamp
        env["CTNG_HOST_SUFFIX"] = host_suffix
    if debug:
        env["CTNG_DEBUG"] = "y"

    if not containerize:
        if not build_volume:
            fail(
                "ctng_invocation: build_volume is required for "
                + "non-containerized builds",
            )
        env["CTNG_BUILD_VOLUME"] = build_volume
        env["CTNG_OUT_DIR"] = repo_host_path(ctx, "out")
        env["CTNG_PATCH_DIR"] = repo_host_path(ctx, "toolchain-patches")
        return ctx.subprocess(
            argv = [
                ctx.repo_path("recipes/ctng/ruyi-build-ctng-inner-darwin"),
                defconfig_path,
            ],
            cwd = ctx.repo_root,
            env = env,
            produces = [ctx.artifact(glob = g) for g in artifact_globs],
        )

    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

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
                    ctx.repo_path("recipes/ctng/ruyi-build-ctng-inner"),
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
                ctx.repo_path("recipes/qemu/ruyi-build-qemu-inner"),
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

    if arch not in ("x86_64", "aarch64", "riscv64"):
        fail("llvm_invocation: arch must be one of x86_64/aarch64/riscv64 (got %r)" % arch)

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
                ctx.repo_path("recipes/llvm/ruyi-build-llvm-inner"),
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


def dynamorio_invocation(ctx, config, arch, builder_tag = None):
    """Plan a ``ruyi-build-dynamorio-inner`` run.

    Mirrors the mount set of the legacy ``ruyi-build-dynamorio``
    wrapper: ``out`` and ``work`` (rw), the inner script (ro). Uses
    ``--user root`` per the legacy wrapper (FIXME carried over).
    Configuration that the legacy wrapper hardcoded in the inner
    script is passed as environment variables; ``config`` is a dict
    of those variables and must carry at least:

    ``P``, ``PV``, ``RUYI_DATESTAMP``, ``SRC_URI``, ``SRC_REF``.

    Artifact glob is derived from ``arch``:

    ``dynamorio-riscv-{PV}-ruyi.{RUYI_DATESTAMP}.{arch}.tar.zst``
    """

    if arch not in ("x86_64", "aarch64", "riscv64"):
        fail(
            "dynamorio_invocation: arch must be one of x86_64/aarch64/riscv64 "
            + "(got %r)" % arch,
        )

    _required = [
        "P",
        "PV",
        "RUYI_DATESTAMP",
        "SRC_URI",
        "SRC_REF",
    ]
    for k in _required:
        if k not in config:
            fail("dynamorio_invocation: config is missing required key %r" % k)

    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

    artifact_glob = "dynamorio-riscv-%s-ruyi.%s.%s.tar.zst" % (
        config["PV"],
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
            mounts_ro = [
                (
                    ctx.repo_path("recipes/dynamorio/ruyi-build-dynamorio-inner"),
                    "/usr/local/bin/ruyi-build-dynamorio-inner",
                ),
            ],
            env = config,
            extra_docker_args = ["--user", "root"],
            argv = [
                "ruyi-build-dynamorio-inner",
                arch,
            ],
        ),
        cwd = ctx.repo_root,
        produces = [ctx.artifact(glob = artifact_glob)],
    )


def box64_invocation(ctx, config, arch, src_tarball = None, builder_tag = None):
    """Plan a ``ruyi-build-box64-inner`` run.

    Mirrors the mount set of the legacy ``ruyi-build-box64`` wrapper:
    ``out`` and ``work`` (rw), the inner script and the optional source
    tarball (ro), and ``/tmp/mem`` as a real tmpfs.  Configuration that
    the legacy wrapper read from a sourced shell file is passed as
    environment variables instead; ``config`` is a dict of those
    variables and must carry at least:

    ``P``, ``PV``, ``RUYI_DATESTAMP``, ``SRC_URI``.

    Additional optional keys such as ``TAR_STRIP_COMPONENTS`` and
    ``USE_MEM`` may also be included and are passed through verbatim.

    ``arch`` must be ``arm64`` or ``riscv64`` (amd64 is explicitly
    rejected -- box64 emulates amd64, so building for the native host
    is useless).

    Artifact glob is derived from ``arch``:

    ``{P}.{arch}.tar.zst``
    """

    if arch not in ("arm64", "riscv64"):
        fail(
            "box64_invocation: arch must be arm64 or riscv64 "
            + "(got %r)" % arch,
        )

    _required = [
        "P",
        "PV",
        "RUYI_DATESTAMP",
        "SRC_URI",
    ]
    for k in _required:
        if k not in config:
            fail("box64_invocation: config is missing required key %r" % k)

    image = builder_tag if builder_tag else pkgbuilder_image_tag("unified", "amd64")

    mounts_ro = [
        (
            ctx.repo_path("recipes/box64/ruyi-build-box64-inner"),
            "/usr/local/bin/ruyi-build-box64-inner",
        ),
    ]
    if src_tarball:
        mounts_ro.append((src_tarball, "/tmp/src.tar.xz"))

    artifact_glob = "%s.%s.tar.zst" % (config["P"], arch)

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
                "ruyi-build-box64-inner",
                arch,
            ],
        ),
        cwd = ctx.repo_root,
        produces = [ctx.artifact(glob = artifact_glob)],
    )


def wlink_invocation(ctx, config, arch, builder_tag = None):
    """Plan a ``ruyi-build-wlink-inner`` run.

    Mirrors the mount set of the legacy ``ruyi-build-wlink`` wrapper:
    ``out`` and ``work`` (rw), the inner script (ro). Uses the
    ``rust-musl`` builder image instead of the ``unified`` one.
    Configuration that the legacy wrapper supplied as command-line
    arguments is passed as environment variables; ``config`` is a
    dict of those variables and must carry at least:

    ``P``, ``PV``, ``RUYI_DATESTAMP``, ``SRC_URI``, ``SRC_REF``.

    ``arch`` must be ``aarch64``, ``riscv64``, or ``x86_64``.

    Artifact glob is derived from ``arch``:

    ``wlink-*.{arch}.tar.gz``
    """

    if arch not in ("aarch64", "riscv64", "x86_64"):
        fail(
            "wlink_invocation: arch must be aarch64, riscv64 or x86_64 "
            + "(got %r)" % arch,
        )

    _required = [
        "P",
        "PV",
        "RUYI_DATESTAMP",
        "SRC_URI",
        "SRC_REF",
    ]
    for k in _required:
        if k not in config:
            fail("wlink_invocation: config is missing required key %r" % k)

    image = builder_tag if builder_tag else pkgbuilder_image_tag("rust-musl", "amd64")

    artifact_glob = "wlink-*.%s.tar.gz" % arch

    return ctx.subprocess(
        argv = docker_run(
            image = image,
            mounts_rw = [
                (repo_host_path(ctx, "out"), "/out"),
                (repo_host_path(ctx, "work"), "/work"),
            ],
            mounts_ro = [
                (
                    ctx.repo_path("recipes/wlink/ruyi-build-wlink-inner"),
                    "/usr/local/bin/ruyi-build-wlink-inner",
                ),
            ],
            env = config,
            argv = [
                "ruyi-build-wlink-inner",
                arch,
            ],
        ),
        cwd = ctx.repo_root,
        produces = [ctx.artifact(glob = artifact_glob)],
    )
