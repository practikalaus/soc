#!/usr/bin/env bash
set -euo pipefail

base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Optional branding (wrapper-only)
if [[ -f "${base_dir}/branding.sh" ]]; then
  # shellcheck disable=SC1091
  source "${base_dir}/branding.sh"
fi
: "${SOC_BRAND_TITLE:=}"
: "${SOC_ORG_NAME:=Practikal IT Solutions}"
: "${SOC_PRODUCT_NAME:=SOC}"

banner() {
  if [[ -n "${SOC_BRAND_TITLE}" ]]; then
    echo "${SOC_BRAND_TITLE}: $*"
    return 0
  fi
  local prefix
  prefix="${SOC_ORG_NAME}"
  if [[ -n "${SOC_PRODUCT_NAME}" ]]; then
    prefix+=" — ${SOC_PRODUCT_NAME}"
  fi
  echo "${prefix}: $*"
}

usage() {
  cat <<'EOF'
Run the generated SOC installer (soc-install.sh) for indexer/server/dashboard.

Usage:
  run-soc.sh --major <MAJOR> verify
  run-soc.sh --major <MAJOR> generate-config
  run-soc.sh --major <MAJOR> start-cluster
  run-soc.sh --major <MAJOR> indexer   --node <soc-indexer>
  run-soc.sh --major <MAJOR> server    --node <soc-server>
  run-soc.sh --major <MAJOR> dashboard --node <soc-dashboard>

Options:
  --dry-run     Print commands but do not execute

Notes:
- Requires installer/dist/soc-install.sh (build with build-soc-installer.sh)
- Prefers installer/upstream/<MAJOR>/config.soc.yml if present, else config.yml
- Uses installer/work/<MAJOR>/ as the execution directory
- For all actions except generate-config, expects soc-install-files.tar in work dir
EOF
}

major=""
action=""
node_name=""
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      major="${2:-}"; shift 2 ;;
    verify|generate-config|start-cluster|indexer|server|dashboard)
      action="$1"; shift 1; break ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node)
      node_name="${2:-}"; shift 2 ;;
    --dry-run)
      dry_run=1; shift 1 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$major" || -z "$action" ]]; then
  echo "Missing --major and/or action" >&2
  usage
  exit 2
fi

up_dir="${base_dir}/upstream/${major}"
work_dir="${base_dir}/work/${major}"
soc_installer_src="${base_dir}/dist/soc-install.sh"

if [[ ! -x "${soc_installer_src}" ]]; then
  echo "Missing generated installer: ${soc_installer_src}" >&2
  echo "Build it first: ./build-soc-installer.sh --major ${major}" >&2
  exit 1
fi

if [[ ! -f "${up_dir}/config.yml" ]]; then
  echo "Missing upstream config.yml: ${up_dir}/config.yml" >&2
  echo "Run: ./fetch-upstream.sh --major ${major}" >&2
  exit 1
fi

config_src="${up_dir}/config.soc.yml"
if [[ ! -f "${config_src}" ]]; then
  config_src="${up_dir}/config.yml"
fi

mkdir -p "${work_dir}"
cp -f "${soc_installer_src}" "${work_dir}/soc-install.sh"
cp -f "${config_src}" "${work_dir}/config.yml"
chmod 0755 "${work_dir}/soc-install.sh"

cd "${work_dir}"

run_or_print() {
  if [[ "${dry_run}" -eq 1 ]]; then
    banner "DRY-RUN: $*"
    return 0
  fi
  eval "$@"
}

require_tar() {
  if [[ "${dry_run}" -eq 1 ]]; then
    return 0
  fi
  if [[ ! -f ./soc-install-files.tar ]]; then
    echo "Missing ./soc-install-files.tar in ${work_dir}" >&2
    echo "Generate it first: sudo bash ./soc-install.sh --generate-config-files" >&2
    exit 1
  fi
}

if [[ "${action}" == "verify" ]]; then
  banner "Verifying inputs for ${major}..."
  echo "Upstream: ${up_dir}"
  echo "Workdir:  ${work_dir}"
  [[ -f "${up_dir}/config.soc.yml" ]] && echo "OK: config.soc.yml present (preferred)" || echo "NOTE: config.soc.yml not present"
  [[ -x "${soc_installer_src}" ]] && echo "OK: dist/soc-install.sh present"
  [[ -f "${work_dir}/soc-install-files.tar" ]] && echo "OK: soc-install-files.tar present" || echo "NOTE: soc-install-files.tar not present"
  exit 0
fi

case "${action}" in
  generate-config)
    banner "Running: sudo bash soc-install.sh --generate-config-files"
    run_or_print "sudo bash ./soc-install.sh --generate-config-files"
    ;;
  start-cluster)
    require_tar
    banner "Running: sudo bash soc-install.sh --start-cluster"
    run_or_print "sudo bash ./soc-install.sh --start-cluster"
    ;;
  indexer)
    require_tar
    [[ -n "${node_name}" ]] || { echo "Missing --node" >&2; exit 2; }
    banner "Running: sudo bash soc-install.sh --wazuh-indexer ${node_name}"
    run_or_print "sudo bash ./soc-install.sh --wazuh-indexer ${node_name@Q}"
    ;;
  server)
    require_tar
    [[ -n "${node_name}" ]] || { echo "Missing --node" >&2; exit 2; }
    banner "Running: sudo bash soc-install.sh --wazuh-server ${node_name}"
    run_or_print "sudo bash ./soc-install.sh --wazuh-server ${node_name@Q}"
    ;;
  dashboard)
    require_tar
    [[ -n "${node_name}" ]] || { echo "Missing --node" >&2; exit 2; }
    banner "Running: sudo bash soc-install.sh --wazuh-dashboard ${node_name}"
    run_or_print "sudo bash ./soc-install.sh --wazuh-dashboard ${node_name@Q}"
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    exit 2
    ;;
esac
