#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "${SCRIPT_DIR}"

export NGC_CLI_API_KEY="${NGC_CLI_API_KEY:-${NGC_API_KEY:-}}"
export NIM_CACHE_ROOT="${NIM_CACHE_ROOT:-${HOME}/.cache/nim}"

if [[ -z "${NGC_CLI_API_KEY}" ]]; then
  echo "[ERROR] NGC_CLI_API_KEY or NGC_API_KEY must be set."
  exit 1
fi

if [[ -z "${NVIDIA_API_KEY:-}" ]]; then
  echo "[ERROR] NVIDIA_API_KEY must be set."
  exit 1
fi

mkdir -p \
  "${NIM_CACHE_ROOT}/cosmos-reason2-8b" \
  "${NIM_CACHE_ROOT}/nemotron-nano-9b-v2-fp8"
chmod -R 777 "${NIM_CACHE_ROOT}"

scripts/dev-profile.sh up -p base \
  --hardware-profile DGX-SPARK \
  --llm nvidia/NVIDIA-Nemotron-Nano-9B-v2-FP8 \
  --vlm nvidia/cosmos-reason2-8b
