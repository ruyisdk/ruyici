# Build recipe for llvm/plct @ datestamp 20250915.
#
# Drives the same ruyi-build-llvm-inner entry point as the legacy
# ./ruyi-build-llvm ./llvm-configs/plct-20250915.sh workflow.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "llvm_invocation")

_HOSTS = ["x86_64", "aarch64", "riscv64"]

_PV = "21.1.0"
_DATESTAMP = "20250915"
_COMMIT = "3623fe661ae35c6c80ac221f14d85be76aa870f"
_COMMIT_SHORT = _COMMIT[:12]

_CONFIG = {
    "P": "llvm-plct-%s" % _PV,
    "PV": _PV,
    "RUYI_DATESTAMP": _DATESTAMP,
    "SRC_URI": "https://mirror.iscas.ac.cn/ruyisdk/dist/ruyisdk-llvm-project-%s.src.tar.zst" % _COMMIT,
    "TAR_STRIP_COMPONENTS": "2",
    "LLVM_VENDOR": "RuyiSDK %s RuyiSDK-LLVM-%s (https://github.com/ruyisdk/llvm-project)" % (_DATESTAMP, _COMMIT_SHORT),
    "CLANG_VENDOR": "RuyiSDK",
    "CLANG_REPOSITORY_STRING": "https://github.com/ruyisdk/llvm-project %s RuyiSDK %s" % (_COMMIT, _DATESTAMP),
    "BUG_REPORT_URL": "https://github.com/ruyisdk/llvm-project/issues",
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
