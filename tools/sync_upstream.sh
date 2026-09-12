#!/usr/bin/env bash
# ==============================================================================
# Sync Playerbot mirror and rebase android-termux with upstream mod-playerbots
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

UPSTREAM_URL="https://github.com/mod-playerbots/azerothcore-wotlk.git"
UPSTREAM_BRANCH="Playerbot"
TARGET_BRANCH="android-termux"
AUTO_PUSH=false

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [BRANCH]

Fetches the latest upstream mod-playerbots changes and rebases the target
development branch directly against upstream.

Arguments:
  BRANCH              Target branch to rebase (default: android-termux)

Options:
  -p, --push          Automatically push rebased target branch to origin
  -h, --help          Display this help message and exit
EOF
}

# Parse command-line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -p|--push)
      AUTO_PUSH=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    -*)
      echo "[ERROR] Unknown option: $1" >&2
      show_help
      exit 1
      ;;
    *)
      TARGET_BRANCH="$1"
      shift
      ;;
  esac
done

echo "======================================================================"
echo "Upstream Synchronization: mod-playerbots (branch: ${UPSTREAM_BRANCH})"
echo "Target branch to rebase: ${TARGET_BRANCH}"
echo "Auto-push target: ${AUTO_PUSH}"
echo "======================================================================"

# Ensure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
  echo ""
  echo "[ERROR] You have uncommitted changes in your working tree!" >&2
  echo "Please commit or stash your changes before syncing with upstream." >&2
  git status --short
  exit 1
fi

# Ensure upstream remote exists and points to the Playerbot repo
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Adding upstream remote (${UPSTREAM_URL})..."
  git remote add upstream "${UPSTREAM_URL}"
else
  git remote set-url upstream "${UPSTREAM_URL}"
fi

echo "Fetching latest changes from upstream ${UPSTREAM_BRANCH}..."
git fetch upstream "${UPSTREAM_BRANCH}"

UPSTREAM_COMMIT="$(git rev-parse "upstream/${UPSTREAM_BRANCH}")"

# Switch to target branch if not currently active
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "${CURRENT_BRANCH}" != "${TARGET_BRANCH}" ]; then
  echo "Switching to target branch '${TARGET_BRANCH}'..."
  git checkout "${TARGET_BRANCH}"
fi

BASE_COMMIT="$(git merge-base "${TARGET_BRANCH}" "upstream/${UPSTREAM_BRANCH}")"

if [ "${UPSTREAM_COMMIT}" = "${BASE_COMMIT}" ]; then
  echo ""
  echo "======================================================================"
  echo "Branch '${TARGET_BRANCH}' is already completely up-to-date with upstream ${UPSTREAM_BRANCH}!"
  echo "======================================================================"
  exit 0
fi

echo "Rebasing '${TARGET_BRANCH}' on top of upstream/${UPSTREAM_BRANCH}..."
if git rebase "upstream/${UPSTREAM_BRANCH}"; then
  echo ""
  echo "======================================================================"
  echo "Rebase completed successfully!"
  echo "======================================================================"

  if [ "${AUTO_PUSH}" = true ]; then
    echo "Pushing rebased '${TARGET_BRANCH}' to origin..."
    git push --force-with-lease origin "${TARGET_BRANCH}"
    echo "Successfully pushed '${TARGET_BRANCH}' to origin!"
  elif [ -t 0 ]; then
    read -r -p "Do you want to push rebased '${TARGET_BRANCH}' to origin now? [y/N]: " answer
    if [[ "${answer}" =~ ^[Yy]$ ]]; then
      git push --force-with-lease origin "${TARGET_BRANCH}"
      echo "Successfully pushed '${TARGET_BRANCH}' to origin!"
    else
      echo "Push skipped. To push manually, run:"
      echo "  git push --force-with-lease origin ${TARGET_BRANCH}"
    fi
  else
    echo "To update your remote GitHub repository, run:"
    echo "  git push --force-with-lease origin ${TARGET_BRANCH}"
  fi
else
  echo ""
  echo "[WARN] Rebase encountered merge conflicts."
  echo "Resolve the conflicting files, stage them with 'git add <file>',"
  echo "and continue with: git rebase --continue"
  echo "To abort the rebase: git rebase --abort"
  exit 1
fi
