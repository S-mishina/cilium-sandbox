# Cilium Sandbox

A Kind-based environment for learning Cilium.

## Prerequisites

- Docker
- kind
- kubectl
- helm
- cilium CLI

## Quick Start

```bash
# Create cluster + Install Cilium
make up

# Check status
make cilium-status

# Open Hubble UI
make hubble-ui

# Delete cluster
make down
```

## Port Mappings

| Purpose           | Host  | Container | Notes            |
| ----------------- | ----- | --------- | ---------------- |
| Ingress           | 40000 | 30000     | NodePort         |
| Gateway API       | 40001 | 30001     | hostNetwork mode |
| Hubble Relay      | 4245  | 4245      |                  |
| Hubble UI         | 12001 | 12001     |                  |
| ClickHouse HTTP   | 48123 | 8123      |                  |
| ClickHouse Native | 49000 | 9000      |                  |

## Documentation

See [docs/](./docs/) for details.
