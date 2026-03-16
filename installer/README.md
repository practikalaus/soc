# Installer wrappers

- `fetch-upstream.sh` downloads `wazuh-install.sh` + `config.yml` into `upstream/<major>/`.
- `build-soc-installer.sh` generates `dist/soc-install.sh` (branded) from upstream.
- `run-soc.sh` runs indexer/server/dashboard actions using `dist/soc-install.sh` in `work/<major>/`.

Legacy:
- `run-indexer.sh` is kept for indexer-only flows.

## Branding
- `branding.sh` defines `SOC_ORG_NAME` and `SOC_PRODUCT_NAME` used by the wrapper scripts.
	- `SOC_BRAND_TITLE` is preferred for a single-line banner.

This keeps upstream artifacts separate from your overlay/config repo.
