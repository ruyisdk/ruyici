# Build recipe for llvm/upstream @ datestamp 20250915.
#
# Drives the same ruyi-build-llvm-inner entry point as the legacy
# ./ruyi-build-llvm ./llvm-configs/upstream-20250915.sh workflow.

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "llvm_invocation")

_HOSTS = ["x86_64", "aarch64", "riscv64"]

_PV = "21.1.1"
_DATESTAMP = "20250915"
_COMMIT = "5a86dc996c26299de63effc927075dcbfb924167"
_COMMIT_SHORT = _COMMIT[:12]

_CONFIG = {
    "P": "llvm-%s" % _PV,
    "PV": _PV,
    "RUYI_DATESTAMP": _DATESTAMP,
    "SRC_URI": "https://github.com/llvm/llvm-project/releases/download/llvmorg-%s/llvm-project-%s.src.tar.xz" % (_PV, _PV),
    "LLVM_VENDOR": "RuyiSDK %s Upstream-LLVM-%s (https://github.com/llvm/llvm-project)" % (_DATESTAMP, _COMMIT_SHORT),
    "CLANG_VENDOR": "RuyiSDK",
    "CLANG_REPOSITORY_STRING": "https://github.com/llvm/llvm-project %s RuyiSDK %s" % (_COMMIT, _DATESTAMP),
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
