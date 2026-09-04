#!/usr/bin/env bash
# ==============================================================================
# Configure AzerothCore with Android (Termux) flags
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/azeroth-server}"

mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "======================================================================"
echo "Configuring AzerothCore for Android (Termux)"
echo "Source:         ${REPO_ROOT}"
echo "Build Dir:      ${BUILD_DIR}"
echo "Install Prefix: ${INSTALL_PREFIX}"
echo "======================================================================"

cmake "${REPO_ROOT}" \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
  -DCMAKE_C_COMPILER="${PREFIX}/bin/clang" \
  -DCMAKE_CXX_COMPILER="${PREFIX}/bin/clang++" \
  -DWITH_WARNINGS=1 \
  -DTOOLS=0 \
  -DSCRIPTS=static \
  -DCMAKE_CXX_FLAGS="-D__ANDROID__ -DANDROID -Wno-deprecated-literal-operator" \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--allow-multiple-definition -lunwind" \
  "$@"

echo ""
echo "======================================================================"
echo "Configuration complete! To compile, run:"
echo "  cd build && make -j4 && make install"
echo "======================================================================"
