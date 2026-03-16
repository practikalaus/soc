# Practikal IT Solutions | Security Operations & IT Audit Centre

This repository is a **source-controlled customization layer** for a Wazuh deployment used as the baseline for the Practikal IT Solutions SOC.

It intentionally **does not fork or copy** upstream Wazuh installers/packages. Instead it:
- downloads upstream and generates a branded installer script (`soc-install.sh`) plus `config.yml`
- keeps your organization-specific **overlays** (branding + configs) in git
- provides repeatable scripts to apply overlays after install/upgrade

## Layout
- `installer/` — wrapper scripts to fetch upstream + run assisted installs
- `indexer/overlay/` — files to overlay onto `/etc/wazuh-indexer/`
- `dashboard/overlay/` — files to overlay onto `/etc/wazuh-dashboard/` (and later branding assets)
- `manager/overlay/` — files to overlay onto `/var/ossec/` (rules/decoders/integrations/config)
- `docs/` — internal notes/runbooks

## Quick start
For the GitHub-driven one-liner (similar to upstream quickstart), see docs/quickstart.md.

All-in-one (single node):

- `curl -fsSLO https://raw.githubusercontent.com/practikalaus/soc/main/installer/soc-quickstart.sh && sudo bash ./soc-quickstart.sh -a`

1) Fetch upstream assistant + default config:

- `cd installer && ./fetch-upstream.sh --major 4.14`

2) Build the branded installer:

- `cd installer && ./build-soc-installer.sh --major 4.14`

3) Edit the generated SOC config template:

- `nano installer/upstream/4.14/config.soc.yml`

4) Generate certs/passwords tar (on the node where you generate certs):

- `cd installer && sudo ./run-soc.sh --major 4.14 generate-config`

5) Install indexer on a node (expects `soc-install-files.tar` in `installer/work/<major>/`):

	- `cd installer && sudo ./run-soc.sh --major 4.14 indexer --node soc-indexer`

6) Initialize cluster security (run once on any indexer node):

- `cd installer && sudo ./run-soc.sh --major 4.14 start-cluster`

7) Install SOC server:

- `cd installer && sudo ./run-soc.sh --major 4.14 server --node soc-server`

8) Install SOC dashboard:

- `cd installer && sudo ./run-soc.sh --major 4.14 dashboard --node soc-dashboard`

5) Apply overlays (idempotent):

- `sudo ./indexer/apply-overlay.sh`
- `sudo ./dashboard/apply-overlay.sh`
- `sudo ./manager/apply-overlay.sh`

Optional: create `soc-*` systemd aliases (so you can use `systemctl status soc-indexer` etc.):

- `sudo ./installer/install-service-aliases.sh`

## Notes
- This repo is meant for **internal use**.
- The installed Wazuh Dashboard directory under `/usr/share/wazuh-dashboard` is typically **not readable** by non-root users; customization should be done via overlays and (when needed) building/installing a custom dashboard plugin from source.
