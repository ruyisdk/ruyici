# Path helpers for recipes.
#
# ``ctx.repo_path(rel)`` is realpath-checked and refuses to return a
# path outside the project tree. That is correct for inputs that must
# come from inside the repo (config files, the inner scripts), but too
# strict for bind-mount host paths where the user may have symlinked a
# directory such as ``work/`` to somewhere on a tmpfs. For those we just
# want ``$REPO_ROOT/<rel>`` as a string, handing docker whatever the
# user has arranged on disk.

def repo_host_path(ctx, rel):
    """Return ``<repo_root>/<rel>`` without realpath resolution.

    Use for host paths passed to ``docker -v`` where following symlinks
    to outside the project is intentional.
    """

    if not rel:
        fail("repo_host_path: rel must be non-empty")
    if rel.startswith("/"):
        fail("repo_host_path: rel must be relative (got %r)" % rel)
    return "%s/%s" % (ctx.repo_root, rel)
