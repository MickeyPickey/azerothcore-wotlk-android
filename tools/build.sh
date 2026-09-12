#!/usr/bin/env bash
# ==============================================================================
# Build and Install AzerothCore for Android (Termux)
#
# Automatically:
#   1. Ensures Git submodules are initialized and updated
#   2. Configures CMake with Android/Termux flags (via tools/configure.sh)
#   3. Compiles the server with safe core concurrency to prevent mobile OOMs
#   4. Installs server binaries and server control tools
#
# Usage:
#   ./tools/build.sh                   -> Full build and install (recommended)
#   ./tools/build.sh -j <jobs>         -> Custom concurrency (e.g. -j 4)
#   ./tools/build.sh --clean           -> Clean build directory before building
#   ./tools/build.sh --skip-submodules -> Skip git submodule check
#   ./tools/build.sh --skip-install    -> Compile only without make install
#   ./tools/build.sh -h | --help       -> Show this help message
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export INSTALL_PREFIX="${INSTALL_PREFIX:-$HOME/azeroth-server}"
INSTALL_TOOLS_DIR="${INSTALL_PREFIX}/tools"

# Default concurrency: leave 2 cores free for system/mobile stability
TOTAL_CORES="$(nproc 2>/dev/null || echo 4)"
if [ "${TOTAL_CORES}" -gt 2 ]; then
  DEFAULT_JORES=$(( TOTAL_CORES - 2 ))
else
  DEFAULT_JORES=1
fi
JOBS="${JOBS:-${DEFAULT_JORES}}"

DO_CLEAN=0
CHECK_SUBMODULES=1
DO_INSTALL=1
CMAKE_EXTRA_ARGS=()

# Parse arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -j|--jobs)
      shift
      if [ -n "$1" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        JOBS="$1"
        shift
      else
        echo "Error: -j/--jobs requires a numeric argument." >&2
        exit 1
      fi
      ;;
    --clean)
      DO_CLEAN=1
      shift
      ;;
    --skip-submodules)
      CHECK_SUBMODULES=0
      shift
      ;;
    --skip-install)
      DO_INSTALL=0
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [options] [-- <extra-cmake-args>]"
      echo ""
      echo "Options:"
      echo "  -j, --jobs <N>       Number of parallel compile jobs (default: ${DEFAULT_JORES} on this device)"
      echo "  --clean              Remove build/ directory before configuring"
      echo "  --skip-submodules    Do not run git submodule update"
      echo "  --skip-install       Compile with make but do not run make install"
      echo "  -h, --help           Show this help message"
      echo ""
      echo "Any arguments after '--' are forwarded directly to CMake."
      exit 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do
        CMAKE_EXTRA_ARGS+=("$1")
        shift
      done
      ;;
    *)
      # Pass through any unrecognized flags (e.g. -D options) directly to CMake
      CMAKE_EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

echo "======================================================================"
echo "AzerothCore Android (Termux) Build Pipeline"
echo "Source:         ${REPO_ROOT}"
echo "Build Dir:      ${BUILD_DIR}"
echo "Install Prefix: ${INSTALL_PREFIX}"
echo "Jobs:           ${JOBS} (of ${TOTAL_CORES} CPU cores)"
echo "======================================================================"

# Step 1: Submodule Verification
if [ "${CHECK_SUBMODULES}" -eq 1 ] && [ -f "${REPO_ROOT}/.gitmodules" ]; then
  echo ""
  echo "[1/4] Checking Git submodules..."
  (cd "${REPO_ROOT}" && git submodule update --init --recursive)
  echo "[✓] Git submodules verified."
else
  echo ""
  echo "[1/4] Skipping Git submodule check."
fi

# Step 2: Clean build if requested
if [ "${DO_CLEAN}" -eq 1 ] && [ -d "${BUILD_DIR}" ]; then
  echo ""
  echo "[*] Cleaning build directory: ${BUILD_DIR}..."
  rm -rf "${BUILD_DIR}"
fi

# Step 3: Configure CMake
echo ""
echo "[2/4] Configuring CMake..."
"${SCRIPT_DIR}/configure.sh" "${CMAKE_EXTRA_ARGS[@]}"

# Step 4: Compile
echo ""
echo "[3/4] Compiling AzerothCore (-j${JOBS})..."
cd "${BUILD_DIR}"
make -j"${JOBS}"

# Step 5: Install
if [ "${DO_INSTALL}" -eq 1 ]; then
  echo ""
  echo "[4/4] Installing binaries and tools to ${INSTALL_PREFIX}..."
  make install
  echo "[✓] Installation complete."
else
  echo ""
  echo "[4/4] Skipping installation as requested (--skip-install)."
fi

echo ""
echo "======================================================================"
echo "Build pipeline successfully finished!"
echo "Server binaries and tools installed to: ${INSTALL_PREFIX}"
echo ""
echo "Next steps to run the server:"
echo "  1. Initialize database: ${INSTALL_TOOLS_DIR}/db_setup.sh"
echo "  2. Start server:        ${INSTALL_TOOLS_DIR}/ac_server_start.sh"
echo "  3. Stop server:         ${INSTALL_TOOLS_DIR}/ac_server_stop.sh"
echo "======================================================================"
