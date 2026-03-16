#!/usr/bin/env bash
set -euo pipefail

# Rebrand the installed Wazuh dashboard UI text/assets on-disk.
# This is a pragmatic approach for internal deployments:
# - makes timestamped backups
# - only edits text files that match the searched strings
# - does NOT rename packages/paths/services
#
# Requires root because /usr/share/wazuh-dashboard is not readable by normal users.

usage() {
  cat <<'EOF'
Rebrand the SOC dashboard UI.

Usage:
  sudo ./dashboard/rebrand-dashboard.sh scan
  sudo ./dashboard/rebrand-dashboard.sh apply \
    --from "Wazuh" --to "SOC" \
    --from "Open Source Security" --to "Practikal IT Solutions | Security Operations & IT Audit Centre"

Notes:
- Creates backups under /var/backups/soc-dashboard-branding/<timestamp>/
- Edits only text files (html/js/css/json/yml/md/txt/svg) under /usr/share/wazuh-dashboard/
- After apply, restart: systemctl restart soc-dashboard
EOF
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

action="${1:-}"
shift || true

case "${action}" in
  scan|apply) ;;
  -h|--help|"") usage; exit 0 ;;
  *) echo "Unknown action: ${action}" >&2; usage; exit 2 ;;
esac

root_dir="/usr/share/wazuh-dashboard"
if [[ ! -d "${root_dir}" ]]; then
  echo "Dashboard install dir not found: ${root_dir}" >&2
  exit 1
fi

# Replacement pairs
from_list=()
to_list=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      from_list+=("${2:-}"); shift 2 ;;
    --to)
      to_list+=("${2:-}"); shift 2 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ "${action}" == "apply" ]]; then
  if [[ ${#from_list[@]} -eq 0 || ${#from_list[@]} -ne ${#to_list[@]} ]]; then
    echo "For apply, provide matching --from/--to pairs." >&2
    exit 2
  fi
fi

is_text_target() {
  case "$1" in
    *.html|*.htm|*.js|*.mjs|*.cjs|*.css|*.scss|*.json|*.yml|*.yaml|*.txt|*.md|*.svg)
      return 0 ;;
    *)
      return 1 ;;
  esac
}

scan_files() {
  local needle="$1"
  # Use grep -R on file extensions we consider safe
  find "${root_dir}" -type f \( \
    -name '*.html' -o -name '*.htm' -o -name '*.js' -o -name '*.mjs' -o -name '*.cjs' -o \
    -name '*.css' -o -name '*.scss' -o -name '*.json' -o -name '*.yml' -o -name '*.yaml' -o \
    -name '*.txt' -o -name '*.md' -o -name '*.svg' \
  \) -print0 \
    | xargs -0 -r grep -n --binary-files=without-match -F "${needle}" 2>/dev/null \
    | head -n 200
}

if [[ "${action}" == "scan" ]]; then
  echo "Scanning for common brand strings under ${root_dir}..."
  echo
  for s in "Wazuh" "wazuh" "Open Source Security"; do
    echo "--- matches for: ${s} ---"
    scan_files "${s}" || true
    echo
  done
  echo "Tip: run apply with --from/--to pairs once you decide exact text."
  exit 0
fi

# apply
stamp="$(date +%Y%m%d_%H%M%S)"
backup_dir="/var/backups/soc-dashboard-branding/${stamp}"
mkdir -p "${backup_dir}"

# Gather candidate files by scanning for any 'from' string
mapfile -t candidates < <(
  for from in "${from_list[@]}"; do
    find "${root_dir}" -type f -print0 \
      | xargs -0 -r grep -l --binary-files=without-match -F "${from}" 2>/dev/null || true
  done | sort -u
)

if [[ ${#candidates[@]} -eq 0 ]]; then
  echo "No files matched the provided --from strings. Nothing to do." >&2
  exit 1
fi

# Backup + edit
for f in "${candidates[@]}"; do
  if ! is_text_target "$f"; then
    continue
  fi

  rel="${f#${root_dir}/}"
  mkdir -p "${backup_dir}/$(dirname "$rel")"
  cp -a "$f" "${backup_dir}/${rel}"

  tmp="${f}.soc-tmp"
  cp -a "$f" "$tmp"

  for i in "${!from_list[@]}"; do
    from="${from_list[i]}"
    to="${to_list[i]}"
    # Use python for safe literal replacement
    python3 - <<PY
import io
import os
p = ${tmp!r}
from_s = ${from!r}
to_s = ${to!r}
with open(p,'r',encoding='utf-8',errors='replace') as fh:
    data = fh.read()
new = data.replace(from_s, to_s)
with open(p,'w',encoding='utf-8') as fh:
    fh.write(new)
PY
  done

  # Replace original
  mv -f "$tmp" "$f"
done

echo "Applied branding changes. Backups saved to: ${backup_dir}"
echo "Restart dashboard: systemctl restart soc-dashboard"
