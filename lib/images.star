# Container-image tag table for pkgbuilder images.
#
# Port of containers/_image_tag_base.sh; kept in sync by hand. The two
# must agree as long as both the legacy ruyi-build-* scripts and the
# build-recipe workflow are in use.

_UNIFIED_TAGS = {
    "amd64": "ghcr.io/ruyisdk/ruyi-ci-pkgbuilder-unified:20260403",
}

_RUST_MUSL_TAGS = {
    "amd64": "ghcr.io/ruyisdk/ruyi-ci-pkgbuilder-rust-musl:20250524",
}

_TABLES = {
    "unified": _UNIFIED_TAGS,
    "rust-musl": _RUST_MUSL_TAGS,
}


def pkgbuilder_image_tag(kind, host_arch):
    """Return the full registry reference for a pkgbuilder image.

    Mirrors the ``image_tag_pkgbuilder`` shell function in
    ``containers/_image_tag_base.sh``.
    """

    if kind not in _TABLES:
        fail("pkgbuilder_image_tag: unsupported image kind %r" % kind)
    table = _TABLES[kind]
    if host_arch not in table:
        fail(
            "pkgbuilder_image_tag: unsupported host arch %r for kind %r" %
            (host_arch, kind),
        )
    return table[host_arch]
