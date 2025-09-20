build_flavor="upstream"
P="qemu-8.2.0"
PV="8.2.0"
RUYI_DATESTAMP=20240128
srcfile="${P}.tar.xz"
SRC_URI="https://download.qemu.org/$srcfile"
pkgversion="RuyiSDK $RUYI_DATESTAMP"

USER_TARGETS="riscv32-linux-user,riscv64-linux-user"
SYSTEM_TARGETS="riscv32-softmmu,riscv64-softmmu"
