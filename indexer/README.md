# Indexer overlays

Put files under `indexer/overlay/` to be copied onto `/etc/wazuh-indexer/`.

Typical targets:
- `opensearch.yml`
- `jvm.options.d/*.options`
- `opensearch-security/*.yml` (roles/users/tenants)
