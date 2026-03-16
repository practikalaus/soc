# Runbooks

## Verify indexer
- `curl -k -u admin https://<indexer-ip>:9200`
- `curl -k -u admin https://<indexer-ip>:9200/_cat/nodes?v`

## Services
- `systemctl status soc-indexer`
- `systemctl status soc-dashboard`
- `systemctl status soc-manager`

## Install systemd aliases
- `sudo ./installer/install-service-aliases.sh`
