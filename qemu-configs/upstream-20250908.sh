build_flavor="upstream"
PV="10.0.4"
P="qemu-$PV"
RUYI_DATESTAMP=20250908
srcfile="${P}.tar.xz"
SRC_URI="https://download.qemu.org/$srcfile"
pkgversion="RuyiSDK $RUYI_DATESTAMP, Upstream-QEMU-v$PV"

USER_TARGETS="riscv32-linux-user,riscv64-linux-user"
SYSTEM_TARGETS="riscv32-softmmu,riscv64-softmmu"
