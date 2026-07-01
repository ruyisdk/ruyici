# Build recipe for llvm/plct @ datestamp 20240511.
#
# Drives the same ruyi-build-llvm-inner entry point as the legacy
# ./ruyi-build-llvm ./llvm-configs/plct-20240511.sh workflow.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "llvm_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]

_PV = "17.0.6"
_CONFIG = {
    "P": "llvm-plct-%s" % _PV,
    "PV": _PV,
    "RUYI_DATESTAMP": "20240511",
    "SRC_URI": "https://mirror.iscas.ac.cn/ruyisdk/dist/ruyisdk-llvm-project-544dd2983c6289abfdf72d5372f30d3ae5bf4cb9.src.tar.zst",
    "TAR_STRIP_COMPONENTS": "2",
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
