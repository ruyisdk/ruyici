PV="21.1.1"
RUYI_DATESTAMP=20250915
commit="5a86dc996c26299de63effc927075dcbfb924167"

P="llvm-$PV"
SRC_URI="https://github.com/llvm/llvm-project/releases/download/llvmorg-${PV}/llvm-project-${PV}.src.tar.xz"

LLVM_VENDOR="RuyiSDK $RUYI_DATESTAMP Upstream-LLVM-${commit:0:12} (https://github.com/llvm/llvm-project)"
CLANG_VENDOR="RuyiSDK"
CLANG_REPOSITORY_STRING="https://github.com/llvm/llvm-project ${commit} RuyiSDK $RUYI_DATESTAMP"
BUG_REPORT_URL="https://github.com/ruyisdk/llvm-project/issues"
