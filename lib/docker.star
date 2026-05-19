# Shared ``docker run ...`` argv builder for build recipes.
#
# Encapsulates the mount/tmpfs plumbing that every legacy
# ruyi-build-* outer script was duplicating. Returns a plain list of
# strings suitable for ``ctx.subprocess(argv=...)``. No I/O.

def docker_run(
        image,
        mounts_rw = [],
        mounts_ro = [],
        tmpfs = [],
        env = {},
        extra_docker_args = [],
        argv = []):
    """Build the argv for a ``docker run`` invocation.

    Args:
        image: Fully-qualified image reference.
        mounts_rw: List of ``(host_path, container_path)`` tuples,
            mounted read-write.
        mounts_ro: List of ``(host_path, container_path)`` tuples,
            mounted read-only.
        tmpfs: List of container-side paths to mount as tmpfs.
        env: Dict of environment variables passed via ``-e KEY=VALUE``.
        extra_docker_args: Raw arguments inserted verbatim before the
            image reference (for one-off workarounds such as
            ``--user root``).
        argv: Command to execute inside the container.
    """

    if not image:
        fail("docker_run: image must be non-empty")
    if not argv:
        fail("docker_run: argv must be non-empty")

    out = ["docker", "run", "--rm"]

    for (host, container) in mounts_rw:
        out.append("-v")
        out.append("%s:%s" % (host, container))
    for (host, container) in mounts_ro:
        out.append("-v")
        out.append("%s:%s:ro" % (host, container))
    for path in tmpfs:
        out.append("--tmpfs")
        out.append("%s:exec" % (path, ))  # otherwise defaults to noexec
    for key in sorted(env.keys()):
        out.append("-e")
        out.append("%s=%s" % (key, env[key]))
    for a in extra_docker_args:
        out.append(a)

    out.append(image)
    for a in argv:
        out.append(a)
    return out
