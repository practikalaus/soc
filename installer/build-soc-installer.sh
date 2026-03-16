#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Build a branded SOC installer script from upstream Wazuh assistant.

Output:
  installer/dist/soc-install.sh

Usage:
  build-soc-installer.sh --major <MAJOR>

Example:
  ./build-soc-installer.sh --major 4.14

This script:
- downloads upstream files into installer/upstream/<MAJOR>/ (via fetch-upstream.sh)
- rewrites a few safe, user-facing defaults:
  - tar filename: soc-install-files.tar
  - log filename: /var/log/soc-install.log
  - help text references to the tar filename
  - adds/uses SOC_BRAND_TITLE banner text where appropriate

It does NOT rename packages, service units, or filesystem paths.
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

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${base_dir}/.." && pwd)"

# Load branding
if [[ -f "${base_dir}/branding.sh" ]]; then
  # shellcheck disable=SC1091
  source "${base_dir}/branding.sh"
fi
: "${SOC_BRAND_TITLE:=Practikal IT Solutions | Security Operations & IT Audit Centre}"

"${base_dir}/fetch-upstream.sh" --major "$major"

in_file="${base_dir}/upstream/${major}/wazuh-install.sh"
out_file="${base_dir}/dist/soc-install.sh"

if [[ ! -f "${in_file}" ]]; then
  echo "Missing upstream script: ${in_file}" >&2
  exit 1
fi

IN_FILE="${in_file}" OUT_FILE="${out_file}" SOC_BRAND_TITLE="${SOC_BRAND_TITLE}" \
python3 - <<'PY'
import os
import re

in_file = os.environ["IN_FILE"]
out_file = os.environ["OUT_FILE"]
brand_title = os.environ.get('SOC_BRAND_TITLE', '').strip()

with open(in_file, 'r', encoding='utf-8', errors='replace') as f:
    src = f.read()

# 1) Change tar filename constant
src = src.replace('readonly tar_file_name="wazuh-install-files.tar"',
                  'readonly tar_file_name="soc-install-files.tar"')

# 2) Change default log file name.
# - When running as root (normal installs): /var/log/soc-install.log
# - When running as non-root (--help/--version): /tmp/soc-install-<uid>.log
# This avoids sticky-dir hardening issues when root tries to append to a user-owned file.
src = src.replace(
  'readonly logfile="/var/log/wazuh-install.log"',
  'logfile="/tmp/soc-install-${UID}.log"\nif [ "${EUID}" -eq 0 ]; then\n  logfile="/var/log/soc-install.log"\nfi\nreadonly logfile'
)

# 3) Update help text that hardcodes tar name (keep other technical strings intact)
src = src.replace('wazuh-install-files.tar', 'soc-install-files.tar')

# 3b) SOC-brand the --version output labels (keep the actual version variables unchanged)
src = src.replace('common_logger "Wazuh version: ${wazuh_version}"',
                  'common_logger "SOC baseline (Wazuh) version: ${wazuh_version}"')
src = src.replace('common_logger "Wazuh installation assistant version: ${wazuh_install_vesion}"',
                  'common_logger "SOC installer version: ${wazuh_install_vesion}"')

# Also brand the normal startup message.
src = src.replace('common_logger "Starting Wazuh installation assistant. Wazuh version:',
                  'common_logger "Starting SOC installer. SOC baseline (Wazuh) version:')

# 3c) Reduce Wazuh naming in common log labels (messages only).
# Keep baseline identifiers where important; avoid changing service/package/path names.
log_replacements = {
  '--- Removing existing Wazuh installation ---': '--- Removing existing SOC installation ---',
  'Removing Wazuh manager.': 'Removing SOC manager.',
  'Removing Wazuh indexer.': 'Removing SOC indexer.',
  'Removing Wazuh dashboard.': 'Removing SOC dashboard.',
  'Wazuh manager removed.': 'SOC manager removed.',
  'Wazuh indexer removed.': 'SOC indexer removed.',
  'Wazuh dashboard removed.': 'SOC dashboard removed.',
  'Starting Wazuh indexer installation.': 'Starting SOC indexer installation.',
  'Wazuh indexer installation finished.': 'SOC indexer installation finished.',
  'Wazuh indexer post-install configuration finished.': 'SOC indexer post-install configuration finished.',
  'Initializing Wazuh indexer cluster security settings.': 'Initializing SOC indexer cluster security settings.',
  'Wazuh indexer cluster security configuration initialized.': 'SOC indexer cluster security configuration initialized.',
  'Wazuh indexer cluster initialized.': 'SOC indexer cluster initialized.',
  'Starting the Wazuh manager installation.': 'Starting SOC manager installation.',
  'Wazuh manager installation finished.': 'SOC manager installation finished.',
  'Wazuh manager vulnerability detection configuration finished.': 'SOC manager vulnerability detection configuration finished.',
  'Starting Wazuh dashboard installation.': 'Starting SOC dashboard installation.',
  'Wazuh dashboard installation finished.': 'SOC dashboard installation finished.',
  'Wazuh dashboard post-install configuration finished.': 'SOC dashboard post-install configuration finished.',
  'Initializing Wazuh dashboard web application.': 'Initializing SOC dashboard web application.',
  'Wazuh dashboard web application initialized.': 'SOC dashboard web application initialized.',
  'Wazuh manager already installed.': 'SOC manager already installed.',
  'Wazuh indexer already installed.': 'SOC indexer already installed.',
  'Wazuh dashboard already installed.': 'SOC dashboard already installed.',
}

for old, new in log_replacements.items():
  src = src.replace(old, new)

# Placeholder in the final summary output
src = src.replace('<wazuh-dashboard-ip>', '<soc-dashboard-ip>')

# 4) Add a small brand banner at the start of main() after root check (best-effort, safe)
# Insert after: common_logger "Verbose logging redirected to ${logfile}"
needle = 'common_logger "Verbose logging redirected to ${logfile}"'
if needle in src and brand_title:
    insertion = (
        needle +
        "\n    common_logger \"" + brand_title.replace('"', '\\"') + "\""
    )
    src = src.replace(needle, insertion, 1)

# 5) Add a short header indicating this is a generated file
header = (
    "# --- SOC wrapper note ---\n"
    "# This file is generated by installer/build-soc-installer.sh from upstream Wazuh.\n"
    "# Local branding changes are applied (tar/log filenames, banner text).\n"
    "# ---\n\n"
)

# Place header after shebang
if src.startswith('#!/bin/bash'):
    src = '#!/bin/bash\n\n' + header + src[len('#!/bin/bash\n\n'):]
elif src.startswith('#!/usr/bin/env bash'):
    src = '#!/usr/bin/env bash\n\n' + header + src[len('#!/usr/bin/env bash\n\n'):]
else:
    src = header + src

with open(out_file, 'w', encoding='utf-8') as f:
    f.write(src)
PY

chmod 0755 "${out_file}"

# Basic sanity checks
bash -n "${out_file}"

if ! grep -q 'readonly tar_file_name="soc-install-files.tar"' "${out_file}"; then
  echo "ERROR: tar_file_name was not rewritten as expected" >&2
  exit 1
fi

echo "Built: ${out_file}"
echo "Tar output name inside installer: soc-install-files.tar"
