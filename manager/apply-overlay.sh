#!/usr/bin/env bash
set -euo pipefail

# Applies repo overlay files onto /var/ossec (Wazuh manager)
# This is where custom rules/decoders/config/integrations typically live.
# Idempotent: copies files, does not delete unknown files.

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src_dir="${repo_root}/manager/overlay"

dst_dir="/var/ossec"

restart_unit() {
  if command -v systemctl >/dev/null 2>&1; then
    if systemctl status soc-manager.service >/dev/null 2>&1; then
      systemctl restart soc-manager.service
      return 0
    fi
    echo "Missing systemd alias: soc-manager.service" >&2
    echo "Install aliases first: sudo ./installer/install-service-aliases.sh" >&2
    exit 1
  fi
}

if [[ ! -d "$src_dir" ]]; then
  echo "Overlay dir not found: $src_dir" >&2
  exit 1
fi

if [[ -z "$(find "$src_dir" -type f -print -quit)" ]]; then
  echo "No overlay files present in $src_dir (nothing to apply)."
  exit 0
fi

if command -v rsync >/dev/null 2>&1; then
  rsync -a --chmod=D750,F640 "$src_dir/" "$dst_dir/"
else
  (cd "$src_dir" && find . -type f -print0) | while IFS= read -r -d '' rel; do
    rel_path="${rel#./}"
    install -D -m 0640 "$src_dir/$rel_path" "$dst_dir/$rel_path"
  done
fi

echo "Applied manager overlay to ${dst_dir}"

echo "Restarting service (soc-manager if available)..."
restart_unit
echo "You can check: systemctl status soc-manager"
