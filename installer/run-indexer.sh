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
Wrapper around the generated soc-install.sh for indexer-related steps.

Usage:
  run-indexer.sh --major <MAJOR> verify
  run-indexer.sh --major <MAJOR> generate-config
  run-indexer.sh --major <MAJOR> start-cluster
  run-indexer.sh --major <MAJOR> indexer --node <node-name>

  run-indexer.sh --major <MAJOR> <action> --dry-run

Notes:
- Uses generated installer in installer/dist/soc-install.sh (build with build-soc-installer.sh)
- Uses working dir installer/work/<MAJOR>/
- Expects config.soc.yml (preferred) or config.yml in upstream dir.
- For indexer install, expects soc-install-files.tar in the work dir.
EOF
}

major=""
action=""
node_name=""
dry_run=0

# Parse leading flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --major)
      major="${2:-}"; shift 2 ;;
    verify|generate-config|start-cluster|indexer)
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

# Parse action-specific flags
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

if [[ ! -x "${up_dir}/wazuh-install.sh" ]]; then
  echo "Upstream script not found: ${up_dir}/wazuh-install.sh" >&2
  echo "Run: ./fetch-upstream.sh --major ${major}" >&2
  exit 1
fi
if [[ ! -f "${up_dir}/config.yml" ]]; then
  echo "Upstream config not found: ${up_dir}/config.yml" >&2
  echo "Run: ./fetch-upstream.sh --major ${major}" >&2
  exit 1
fi

config_src="${up_dir}/config.soc.yml"
if [[ ! -f "${config_src}" ]]; then
  config_src="${up_dir}/config.yml"
fi

mkdir -p "${work_dir}"

# Copy artifacts into the work dir (keeps work dir self-contained)
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

if [[ "${action}" == "verify" ]]; then
  banner "Verifying installer inputs for ${major}..."
  echo "Upstream: ${up_dir}"
  echo "Workdir:  ${work_dir}"
  [[ -x "${up_dir}/wazuh-install.sh" ]] && echo "OK: upstream wazuh-install.sh present"
  if [[ -f "${up_dir}/config.soc.yml" ]]; then
    echo "OK: SOC config template present (config.soc.yml)"
  else
    echo "NOTE: SOC config template not present; using upstream config.yml"
  fi
  if [[ -f "${work_dir}/soc-install-files.tar" ]]; then
    echo "OK: soc-install-files.tar present in workdir"
  else
    echo "NOTE: soc-install-files.tar not present yet (required for indexer/start-cluster)."
  fi
  exit 0
fi

case "$action" in
  generate-config)
    banner "Running: bash soc-install.sh --generate-config-files"
    run_or_print "bash ./soc-install.sh --generate-config-files"
    ;;
  start-cluster)
    if [[ ! -f "./soc-install-files.tar" ]]; then
      echo "Missing ./soc-install-files.tar in ${work_dir}" >&2
      exit 1
    fi
    banner "Running: bash soc-install.sh --start-cluster"
    run_or_print "bash ./soc-install.sh --start-cluster"
    ;;
  indexer)
    if [[ -z "$node_name" ]]; then
      echo "Missing --node <node-name>" >&2
      exit 2
    fi
    if [[ ! -f "./soc-install-files.tar" ]]; then
      echo "Missing ./soc-install-files.tar in ${work_dir}" >&2
      echo "Generate it on the config node with: generate-config (or copy it here)." >&2
      exit 1
    fi
    banner "Running: bash soc-install.sh --wazuh-indexer ${node_name}"
    run_or_print "bash ./soc-install.sh --wazuh-indexer ${node_name@Q}"
    ;;
  *)
    echo "Unknown action: ${action}" >&2
    exit 2
    ;;
esac
