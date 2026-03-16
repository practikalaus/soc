#!/usr/bin/env bash
set -euo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional branding (wrapper-only; does not modify upstream artifacts)
if [[ -f "${base_dir}/branding.sh" ]]; then
  # shellcheck disable=SC1091
  source "${base_dir}/branding.sh"
fi
: "${SOC_BRAND_TITLE:=}"
: "${SOC_ORG_NAME:=Practikal IT Solutions}"
: "${SOC_PRODUCT_NAME:=SOC}"

usage() {
  cat <<'EOF'
Fetch upstream Wazuh installation assistant artifacts.

Usage:
  fetch-upstream.sh --major <MAJOR>

Examples:
  ./fetch-upstream.sh --major 4.14

Downloads:
  - https://packages.wazuh.com/<MAJOR>/wazuh-install.sh
  - https://packages.wazuh.com/<MAJOR>/config.yml

Files are stored under:
  installer/upstream/<MAJOR>/
EOF
}

major=""
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

if [[ -z "$major" ]]; then
  echo "Missing --major" >&2
  usage
  exit 2
fi

out_dir="${base_dir}/upstream/${major}"
mkdir -p "$out_dir"

curl -fsSLo "${out_dir}/wazuh-install.sh" "https://packages.wazuh.com/${major}/wazuh-install.sh"
curl -fsSLo "${out_dir}/config.yml" "https://packages.wazuh.com/${major}/config.yml"
chmod 0755 "${out_dir}/wazuh-install.sh"

# Create a SOC-flavored config template (keeps upstream config.yml intact)
OUT_DIR="${out_dir}" python3 - <<'PY'
import os
from pathlib import Path

out_dir = Path(os.environ["OUT_DIR"])
src_path = out_dir / "config.yml"
dst_path = out_dir / "config.soc.yml"

text = src_path.read_text(encoding="utf-8", errors="replace")

# Minimal, deterministic replacements (keeps the same structure/comments)
text = text.replace("- name: node-1", "- name: soc-indexer")
text = text.replace("- name: wazuh-1", "- name: soc-server")
text = text.replace("- name: dashboard", "- name: soc-dashboard")

dst_path.write_text(text, encoding="utf-8")
PY

if [[ -n "${SOC_BRAND_TITLE}" ]]; then
  echo "${SOC_BRAND_TITLE}: fetched upstream artifacts into: ${out_dir}"
else
  prefix="${SOC_ORG_NAME}"
  if [[ -n "${SOC_PRODUCT_NAME}" ]]; then
    prefix+=" — ${SOC_PRODUCT_NAME}"
  fi
  echo "${prefix}: fetched upstream artifacts into: ${out_dir}"
fi

echo "Generated SOC config template: ${out_dir}/config.soc.yml"
