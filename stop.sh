#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "${SCRIPT_DIR}"

scripts/dev-profile.sh down

echo "[INFO] VSS stopped."
echo "[INFO] Persistent model caches are preserved under: ${NIM_CACHE_ROOT:-${HOME}/.cache/nim}"
