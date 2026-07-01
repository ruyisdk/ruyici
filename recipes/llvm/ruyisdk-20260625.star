# Source: https://github.com/ruyisdk/llvm-project/commit/15a6990a121f883ac215df2fc2677c5ace23ec41

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "llvm_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]

_PV = "22.1.8"
_DATESTAMP = "20260625"
_COMMIT = "15a6990a121f883ac215df2fc2677c5ace23ec41"
_COMMIT_SHORT = _COMMIT[:12]

_CONFIG = {
    "P": "llvm-ruyisdk-%s" % _PV,
    "PV": _PV,
    "RUYI_DATESTAMP": _DATESTAMP,
    "SRC_URI": "https://mirror.iscas.ac.cn/ruyisdk/dist/ruyisdk-llvm-project-%s.src.tar.zst" % _COMMIT,
    "TAR_STRIP_COMPONENTS": "1",
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
