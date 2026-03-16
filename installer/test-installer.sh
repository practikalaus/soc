#!/usr/bin/env bash
set -euo pipefail

# Non-root smoke test for the wrapper-based installer.
# Does not install packages. It only:
# - checks bash syntax
# - fetches upstream artifacts
# - builds the branded installer (soc-install.sh)
# - runs safe commands (help/version) that don't require root

major="4.14"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [--major ${major}]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      major="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${base_dir}/.." && pwd)"

cd "${repo_root}"

echo "[1/4] Bash syntax check"
bash -n installer/fetch-upstream.sh installer/build-soc-installer.sh installer/run-indexer.sh installer/install-service-aliases.sh

echo "[2/4] Fetch upstream artifacts (major=${major})"
installer/fetch-upstream.sh --major "${major}"

echo "[3/4] Build branded installer (soc-install.sh)"
installer/build-soc-installer.sh --major "${major}"

echo "[4/4] Safe runtime checks (no install)"
"${repo_root}/installer/dist/soc-install.sh" --version
"${repo_root}/installer/dist/soc-install.sh" --help >/dev/null || true

echo "OK: installer smoke test completed (no install performed)."
