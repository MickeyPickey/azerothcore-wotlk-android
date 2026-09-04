#!/usr/bin/env bash
# ==============================================================================
# Script to pull and update AzerothCore modules
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_DIR="${REPO_ROOT}/modules"
CONF_DIST="${REPO_ROOT}/conf/dist/modules.list"
CONF_FILE="${REPO_ROOT}/conf/modules.list"

# Allow passing a custom config file as the first argument
if [ -n "$1" ]; then
  CONF_FILE="$1"
fi

if [ ! -f "${CONF_FILE}" ]; then
  if [ -f "${CONF_DIST}" ]; then
    echo "Creating initial ${CONF_FILE} from template..."
    cp "${CONF_DIST}" "${CONF_FILE}"
    echo "Please edit ${CONF_FILE} to uncomment the modules you want to enable."
    exit 0
  else
    echo "Error: Config file not found at ${CONF_FILE}" >&2
    exit 1
  fi
fi

mkdir -p "${MODULES_DIR}"

total=0
cloned=0
updated=0
skipped=0
warnings=0

echo "Reading modules from: ${CONF_FILE}"
echo "Target directory:    ${MODULES_DIR}"
echo "======================================================================"

while IFS= read -r line || [ -n "${line}" ]; do
  # Strip leading and trailing whitespace
  line="$(echo "${line}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  # Skip empty lines or commented lines
  if [ -z "${line}" ] || [[ "${line}" =~ ^# ]]; then
    continue
  fi

  total=$((total + 1))

  # Parse URL and optional ref (branch/tag/commit)
  read -r repo_url target_ref _ <<< "${line}"

  mod_name="$(basename "${repo_url}" .git)"
  mod_path="${MODULES_DIR}/${mod_name}"

  echo ""
  echo "[${total}] Processing: ${mod_name}"

  if [ ! -d "${mod_path}" ]; then
    echo "  -> Directory does not exist. Cloning repository..."
    if [ -n "${target_ref}" ]; then
      # Try shallow clone with specific branch/tag
      if git clone --depth 1 --branch "${target_ref}" "${repo_url}" "${mod_path}" 2>/dev/null; then
        echo "  -> Cloned branch/tag '${target_ref}' (shallow)."
        cloned=$((cloned + 1))
      else
        # Fallback for commit hashes (which cannot always be cloned directly with -b)
        echo "  -> Branch checkout failed, falling back to full clone for commit ${target_ref}..."
        if git clone "${repo_url}" "${mod_path}"; then
          (cd "${mod_path}" && git checkout "${target_ref}")
          echo "  -> Checked out commit '${target_ref}'."
          cloned=$((cloned + 1))
        else
          echo "  [WARN] Failed to clone ${repo_url}." >&2
          warnings=$((warnings + 1))
        fi
      fi
    else
      if git clone --depth 1 "${repo_url}" "${mod_path}"; then
        echo "  -> Cloned default branch (shallow)."
        cloned=$((cloned + 1))
      else
        echo "  [WARN] Failed to clone ${repo_url}." >&2
        warnings=$((warnings + 1))
      fi
    fi
  else
    if [ ! -d "${mod_path}/.git" ]; then
      echo "  [WARN] ${mod_path} exists but is not a git repository. Skipping."
      skipped=$((skipped + 1))
      continue
    fi

    echo "  -> Module exists. Fetching updates..."
    current_branch="$(git -C "${mod_path}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"

    if [ -n "${target_ref}" ]; then
      echo "  -> Checking out requested target: ${target_ref}"
      if git -C "${mod_path}" checkout "${target_ref}" 2>/dev/null; then
        if [ "${current_branch}" != "HEAD" ]; then
          git -C "${mod_path}" pull --ff-only 2>/dev/null || true
        fi
        echo "  -> Updated to ${target_ref}."
        updated=$((updated + 1))
      else
        echo "  [WARN] Could not checkout '${target_ref}' in ${mod_name}. Skipping."
        warnings=$((warnings + 1))
      fi
    else
      if [ "${current_branch}" = "HEAD" ]; then
        echo "  [WARN] ${mod_name} is in detached HEAD state. Leaving as-is."
        skipped=$((skipped + 1))
      else
        if git -C "${mod_path}" pull --ff-only; then
          echo "  -> Updated ${mod_name} on branch '${current_branch}'."
          updated=$((updated + 1))
        else
          echo "  [WARN] Could not fast-forward ${mod_name} (local modifications may exist). Skipping."
          warnings=$((warnings + 1))
        fi
      fi
    fi
  fi
done < "${CONF_FILE}"

echo ""
echo "======================================================================"
echo "Summary: ${total} modules configured in list"
echo "  Cloned:   ${cloned}"
echo "  Updated:  ${updated}"
echo "  Skipped:  ${skipped}"
echo "  Warnings: ${warnings}"
echo "======================================================================"
if [ "${total}" -eq 0 ]; then
  echo "Notice: All modules in ${CONF_FILE} are currently commented out."
  echo "Uncomment the modules you want and run this script again."
fi
