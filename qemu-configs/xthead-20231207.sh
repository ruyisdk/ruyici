build_flavor="xthead"
P="qemu-6.1.0"
PV="6.1.0"
RUYI_DATESTAMP=20231207
thead_commit_hash=03813c9fe8
srcfile="qemu-xthead-$PV-g$thead_commit_hash.tar.zst"
SRC_URI="https://mirror.iscas.ac.cn/ruyisdk/dist/$srcfile"
pkgversion="T-Head commit $thead_commit_hash, RuyiSDK $RUYI_DATESTAMP"

USER_TARGETS="riscv32-linux-user,riscv64-linux-user"
SYSTEM_TARGETS="riscv32-softmmu,riscv64-softmmu"
