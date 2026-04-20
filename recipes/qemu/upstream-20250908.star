# Build recipe for qemu/upstream @ RuyiSDK datestamp 20250908.
#
# Drives the same ruyi-build-qemu-inner entry point as the legacy
# ./ruyi-build-qemu ./qemu-configs/upstream-20250908.sh ... workflow,
# but with every config value inlined here instead of sourced from a
# separate shell file.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "qemu_invocation")

_PV = "10.0.4"
_RUYI_DATESTAMP = "20250908"
_P = "qemu-%s" % _PV
_SRCFILE = "%s.tar.xz" % _P

_CONFIG = {
    "build_flavor": "upstream",
    "P": _P,
    "PV": _PV,
    "RUYI_DATESTAMP": _RUYI_DATESTAMP,
    "srcfile": _SRCFILE,
    "SRC_URI": "https://download.qemu.org/%s" % _SRCFILE,
    "pkgversion": "RuyiSDK %s, Upstream-QEMU-v%s" % (_RUYI_DATESTAMP, _PV),
    "USER_TARGETS": "riscv32-linux-user,riscv64-linux-user",
    "SYSTEM_TARGETS": "riscv32-softmmu,riscv64-softmmu",
}


def _build(ctx):
    arch = ctx.var("arch", default = "amd64")
    flavor = ctx.var("flavor", default = "both")
    src = ctx.var("src")  # required, no default
    builder_tag = ctx.var("builder_tag", default = "")

    return qemu_invocation(
        ctx,
        config = _CONFIG,
        arch = arch,
        flavor = flavor,
        src_tarball = src,
        builder_tag = builder_tag if builder_tag else None,
    )


RUYI.build.schedule_build(_build, name = "qemu-upstream-20250908")
