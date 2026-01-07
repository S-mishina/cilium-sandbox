# Getting Started

## Overview

This sandbox provides a Kubernetes cluster with Cilium installed. You can choose between Kind or Minikube:

| Platform | Nodes                       | Use Case            |
| -------- | --------------------------- | ------------------- |
| Kind     | 1 control-plane + 2 workers | Quick local testing |
| Minikube | Single node (VM)            | VM-based testing    |

## Official Documentation

- [Cilium Documentation](https://docs.cilium.io/en/stable/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/observability/hubble/)
- [Cilium Network Policy](https://docs.cilium.io/en/stable/security/policy/)
- [Cilium Helm Reference](https://docs.cilium.io/en/stable/helm-reference/)

## Installation

### Option 1: Kind (Recommended)

```bash
make kind-up
```

This command:

1. Creates a Kind cluster with CNI disabled
1. Adds Cilium Helm repository
1. Installs Cilium with Hubble enabled
1. Installs Kyverno and demo pods

### Option 2: Minikube (VM driver)

```bash
# Default driver: qemu2
make minikube-up

# Or specify a different VM driver
make minikube-up MINIKUBE_DRIVER=virtualbox
```

This command:

1. Creates a Minikube cluster with VM driver (CNI disabled)
1. Adds Cilium Helm repository
1. Installs Cilium with Hubble enabled
1. Installs Kyverno and demo pods

## Verify Installation

```bash
make cilium-status
```

Expected output:

```
Cilium:           OK
Operator:         OK
Envoy DaemonSet:  OK
Hubble Relay:     OK
```

## Demo Application

Deploy a simple demo app to test connectivity:

```bash
kubectl apply -f manifests/demo-app/deployment.yaml
```

Test connectivity:

```bash
kubectl exec -n demo client -- curl -s backend/get
```

## Hubble UI

Open Hubble UI to visualize network flows:

```bash
make hubble-ui
```

## Cleanup

```bash
# Kind
make kind-down

# Minikube
make minikube-down
```

## Manual Cilium Installation

If you need to install Cilium separately:

```bash
# For Kind
make cilium-install OVERLAY=kind

# For Minikube
make cilium-install OVERLAY=minikube
```
