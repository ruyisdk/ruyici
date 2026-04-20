# Build recipe for qemu/upstream @ RuyiSDK datestamp 20250908.
#
# Corresponds to the legacy invocation:
#
#     ./ruyi-build-qemu \
#         ./qemu-configs/upstream-20250908.sh \
#         <arch> <flavor> <path-to-qemu-10.0.4.tar.xz>

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "qemu_invocation")

_CONFIG_REL = "qemu-configs/upstream-20250908.sh"


def _build(ctx):
    arch = ctx.var("arch", default = "amd64")
    flavor = ctx.var("flavor", default = "both")
    src = ctx.var("src")  # required, no default
    builder_tag = ctx.var("builder_tag", default = "")

    return qemu_invocation(
        ctx,
        config_path = ctx.repo_path(_CONFIG_REL),
        arch = arch,
        flavor = flavor,
        src_tarball = src,
        builder_tag = builder_tag if builder_tag else None,
    )


RUYI.build.schedule_build(_build, name = "qemu-upstream-20250908")
