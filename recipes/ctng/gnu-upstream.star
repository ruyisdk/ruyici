# Build recipes for toolchain/gnu-upstream.
#
# Registers one scheduled build per supported host architecture. Each
# build corresponds to the legacy invocation:
#
#     ./ruyi-build-ctng ./toolchain-configs/gnu-upstream/host-<host>.defconfig

RUYI = ruyi_plugin_rev(1)

load("ruyi-build://lib/drivers.star", "ctng_invocation")

_HOSTS = ["amd64", "arm64", "riscv64"]


# The amd64 build runs natively on the builder so CT_HOST is unset and
# the resulting tarball has no HOST- prefix; the cross builds for arm64
# and riscv64 hosts do carry a HOST- prefix in their filename.
_ARTIFACT_GLOBS = {
    "amd64": [
        "RuyiSDK-*-Upstream-Sources-riscv64-unknown-linux-gnu.tar.xz",
    ],
    "arm64": [
        "RuyiSDK-*-Upstream-Sources-HOST-aarch64-linux-gnu-riscv64-unknown-linux-gnu.tar.xz",
    ],
    "riscv64": [
        "RuyiSDK-*-Upstream-Sources-HOST-riscv64-linux-gnu-riscv64-unknown-linux-gnu.tar.xz",
    ],
}


def _make_build(host):
    defconfig = "toolchain-configs/gnu-upstream/host-%s.defconfig" % host
    globs = _ARTIFACT_GLOBS[host]

    def build(ctx):
        builder_tag = ctx.var("builder_tag", default = "")
        return ctng_invocation(
            ctx,
            defconfig_path = ctx.repo_path(defconfig),
            artifact_globs = globs,
            builder_tag = builder_tag if builder_tag else None,
        )

    return build


for _host in _HOSTS:
    RUYI.build.schedule_build(_make_build(_host), name = _host)
