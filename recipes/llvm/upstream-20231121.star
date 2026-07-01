# Build recipe for llvm/upstream @ datestamp 20231121.
#
# Drives the same ruyi-build-llvm-inner entry point as the legacy
# ./ruyi-build-llvm ./llvm-configs/upstream-20231121.sh workflow.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "llvm_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]

_PV = "17.0.5"
_CONFIG = {
    "P": "llvm-%s" % _PV,
    "PV": _PV,
    "RUYI_DATESTAMP": "20231121",
    "SRC_URI": "https://github.com/llvm/llvm-project/releases/download/llvmorg-%s/llvm-project-%s.src.tar.xz" % (_PV, _PV),
}


def _make_build(host):
    def build(ctx):
        src = ctx.var("src", default = "")
        builder_tag = ctx.var("builder_tag", default = "")
        return llvm_invocation(
            ctx,
            config = _CONFIG,
            arch = host,
            src_tarball = src if src else None,
            builder_tag = builder_tag if builder_tag else None,
        )

    return build


for _host in _HOSTS:
    RUYI.build.schedule_build(_make_build(_host), name = _host)
