#!/usr/bin/env bash
set -euo pipefail

# Creates systemd unit aliases so you can use:
#   systemctl status soc-indexer
#   systemctl restart soc-dashboard
#   systemctl status soc-manager
# without renaming the underlying Wazuh packages.

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then
  echo "systemctl not found; systemd aliases cannot be installed." >&2
  exit 1
fi

unit_dir="/etc/systemd/system"

link_unit() {
  local alias_unit="$1"      # soc-indexer.service
  local target_unit="$2"     # wazuh-indexer.service

  local target_path
  if [[ -f "/usr/lib/systemd/system/${target_unit}" ]]; then
    target_path="/usr/lib/systemd/system/${target_unit}"
  elif [[ -f "/lib/systemd/system/${target_unit}" ]]; then
    target_path="/lib/systemd/system/${target_unit}"
  else
    echo "Target unit not found on disk: ${target_unit}" >&2
    return 1
  fi

  mkdir -p "${unit_dir}"

  local alias_path="${unit_dir}/${alias_unit}"
  if [[ -L "${alias_path}" || -f "${alias_path}" ]]; then
    # If it already points to the correct target, keep it.
    if [[ "$(readlink -f "${alias_path}" 2>/dev/null || true)" == "${target_path}" ]]; then
      echo "Alias already present: ${alias_unit} -> ${target_unit}"
      return 0
    fi
    echo "Refusing to overwrite existing ${alias_path} (not the expected symlink)." >&2
    return 1
  fi

  ln -s "${target_path}" "${alias_path}"
  echo "Installed alias: ${alias_unit} -> ${target_unit}"
}

link_unit soc-indexer.service wazuh-indexer.service
link_unit soc-dashboard.service wazuh-dashboard.service
link_unit soc-manager.service wazuh-manager.service

systemctl daemon-reload

echo "Done. Try: systemctl status soc-indexer"
