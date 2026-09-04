#!/usr/bin/env bash
# ==============================================================================
# Sync current branch with official AzerothCore upstream master
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

UPSTREAM_URL="https://github.com/azerothcore/azerothcore-wotlk.git"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "======================================================================"
echo "Synchronizing with upstream AzerothCore"
echo "Current branch: ${CURRENT_BRANCH}"
echo "======================================================================"

# Ensure upstream remote exists
if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Adding upstream remote (${UPSTREAM_URL})..."
  git remote add upstream "${UPSTREAM_URL}"
fi

# Ensure working directory is clean
if [ -n "$(git status --porcelain)" ]; then
  echo ""
  echo "[ERROR] You have uncommitted changes in your working tree!" >&2
  echo "Please commit or stash your changes before syncing with upstream." >&2
  git status --short
  exit 1
fi

echo "Fetching latest changes from upstream master..."
git fetch upstream master

UPSTREAM_COMMIT="$(git rev-parse upstream/master)"
BASE_COMMIT="$(git merge-base "${CURRENT_BRANCH}" upstream/master)"

if [ "${UPSTREAM_COMMIT}" = "${BASE_COMMIT}" ]; then
  echo "Your branch is already completely up-to-date with upstream master!"
  exit 0
fi

echo "Rebasing ${CURRENT_BRANCH} on top of upstream/master..."
if git rebase upstream/master; then
  echo ""
  echo "======================================================================"
  echo "Rebase completed successfully!"
  echo "To update your remote GitHub repository, run:"
  echo "  git push --force-with-lease origin ${CURRENT_BRANCH}"
  echo "======================================================================"
else
  echo ""
  echo "[WARN] Rebase encountered merge conflicts."
  echo "Resolve the conflicting files, stage them with 'git add <file>',"
  echo "and continue with: git rebase --continue"
  exit 1
fi
