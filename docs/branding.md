# Branding plan (Wazuh 4.14.x)

## What we can brand safely
1) **Installer experience** (this repo)
- wrapper script banners, prompts, and defaults
- does not modify upstream `wazuh-install.sh`

2) **Dashboard**
- primary path: build and install a custom Wazuh dashboard plugin from source
- secondary path: overlay `/etc/wazuh-dashboard/opensearch_dashboards.yml` settings (titles, default route, etc.)

## What we should avoid
- editing files inside `/usr/share/wazuh-dashboard` in place (package-owned; upgrades overwrite)

## Next
- Decide brand assets: org name, product name, logo SVG/PNG sizes
- Decide desired UI text changes (login page title, sidebar name, etc.)
