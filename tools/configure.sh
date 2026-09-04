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
INSTALL_TOOLS_DIR="${INSTALL_PREFIX}/tools"

mkdir -p "${BUILD_DIR}"
mkdir -p "${INSTALL_TOOLS_DIR}"

echo "======================================================================"
echo "Configuring AzerothCore for Android (Termux)"
echo "Source:         ${REPO_ROOT}"
echo "Build Dir:      ${BUILD_DIR}"
echo "Install Prefix: ${INSTALL_PREFIX}"
echo "Tools Dir:      ${INSTALL_TOOLS_DIR}"
echo "======================================================================"

echo "[+] Syncing server control tools to ${INSTALL_TOOLS_DIR}..."
cp -f -p "${SCRIPT_DIR}/ac_server_start.sh" "${INSTALL_TOOLS_DIR}/"
cp -f -p "${SCRIPT_DIR}/ac_server_stop.sh" "${INSTALL_TOOLS_DIR}/"
cp -f -p "${SCRIPT_DIR}/db_setup.sh" "${INSTALL_TOOLS_DIR}/"
chmod +x "${INSTALL_TOOLS_DIR}/ac_server_start.sh" \
  "${INSTALL_TOOLS_DIR}/ac_server_stop.sh" \
  "${INSTALL_TOOLS_DIR}/db_setup.sh"
echo "[✓] Tools copied successfully."
echo ""

cd "${BUILD_DIR}"

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
echo ""
echo "After compilation and installation, manage the server using:"
echo "  ${INSTALL_TOOLS_DIR}/ac_server_start.sh"
echo "  ${INSTALL_TOOLS_DIR}/ac_server_stop.sh"
echo "======================================================================"
