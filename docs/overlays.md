# Overlay conventions

Overlays are copied onto the target host paths by the `apply-overlay.sh` scripts.

## Where to put files
- Indexer overlays → `indexer/overlay/...` maps to `/etc/wazuh-indexer/...`
- Dashboard overlays → `dashboard/overlay/...` maps to `/etc/wazuh-dashboard/...`
- Manager overlays → `manager/overlay/...` maps to `/var/ossec/...`

## Example
To manage the indexer config:
- create `indexer/overlay/opensearch.yml`
- run `sudo ./indexer/apply-overlay.sh`

## Safety rules
- Overlays should be minimal and focused.
- Prefer additive changes; avoid deleting unknown files.
- After applying, restart the relevant service.
