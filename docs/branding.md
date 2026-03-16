# Branding plan (Wazuh 4.14.x)

## What we can brand safely
1) **Installer experience** (this repo)
- wrapper script banners, prompts, and defaults
- does not modify upstream `wazuh-install.sh`

2) **Dashboard**
- primary path: build and install a custom Wazuh dashboard plugin from source
- secondary path: overlay `/etc/wazuh-dashboard/opensearch_dashboards.yml` settings (titles, default route, etc.)

## Pragmatic on-host UI rebrand (internal use)
If you want the installed UI text to say SOC (title/footer/etc.), use:

- `sudo ./dashboard/rebrand-dashboard.sh scan`
- `sudo ./dashboard/rebrand-dashboard.sh apply --from "Wazuh" --to "SOC"`

This makes backups under `/var/backups/soc-dashboard-branding/` and only edits text files under `/usr/share/wazuh-dashboard/`.

## What we should avoid
- editing files inside `/usr/share/wazuh-dashboard` in place (package-owned; upgrades overwrite)

## Next
- Decide brand assets: org name, product name, logo SVG/PNG sizes
- Decide desired UI text changes (login page title, sidebar name, etc.)
