PV="21.1.0"
RUYI_DATESTAMP=20250915
commit="3623fe661ae35c6c80ac221f14d85be76aa870f"

P="llvm-plct-$PV"
SRC_URI="https://mirror.iscas.ac.cn/ruyisdk/dist/ruyisdk-llvm-project-${commit}.src.tar.zst"
TAR_STRIP_COMPONENTS=2

LLVM_VENDOR="RuyiSDK $RUYI_DATESTAMP RuyiSDK-LLVM-${commit:0:12} (https://github.com/ruyisdk/llvm-project)"
CLANG_VENDOR="RuyiSDK"
CLANG_REPOSITORY_STRING="https://github.com/ruyisdk/llvm-project ${commit} RuyiSDK $RUYI_DATESTAMP"
BUG_REPORT_URL="https://github.com/ruyisdk/llvm-project/issues"
