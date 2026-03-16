# Manager overlays

Put files under `manager/overlay/` to be copied onto `/var/ossec/`.

Typical targets:
- `etc/ossec.conf` (careful; prefer small managed snippets)
- `etc/rules/*.xml`
- `etc/decoders/*.xml`
- `integrations/*.py`
