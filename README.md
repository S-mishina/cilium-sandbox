# Cilium Sandbox

A Kind/Minikube-based environment for learning Cilium.

## Prerequisites

- Docker
- kind or minikube
- kubectl
- helm
- cilium CLI

## Quick Start

### Kind (default)

```bash
# Create cluster + Install Cilium
make kind-up

# Check status
make cilium-status

# Open Hubble UI
make hubble-ui

# Delete cluster
make kind-down
```

### Minikube (VM driver)

```bash
# Create cluster + Install Cilium (default: qemu2)
make minikube-up

# Use different VM driver
make minikube-up MINIKUBE_DRIVER=virtualbox

# Check status
make cilium-status

# Open Hubble UI
make hubble-ui

# Delete cluster
make minikube-down
```

## Project Structure

```
.
├── overlays/
│   ├── kind/
│   │   └── cilium-values.yaml   # Kind Cilium settings
│   └── minikube/
│       └── cilium-values.yaml   # Minikube Cilium settings
├── base/
│   └── kyverno/                 # Kyverno settings
├── kind-config.yaml             # Kind cluster config
├── minikube-config.yaml         # Minikube cluster config
└── Makefile
```

## Port Mappings (Kind)

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
