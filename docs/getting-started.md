# Getting Started

## Overview

This sandbox provides a 3-node Kind cluster with Cilium installed:

- 1 control-plane
- 2 workers

## Official Documentation

- [Cilium Documentation](https://docs.cilium.io/en/stable/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/observability/hubble/)
- [Cilium Network Policy](https://docs.cilium.io/en/stable/security/policy/)
- [Cilium Helm Reference](https://docs.cilium.io/en/stable/helm-reference/)

## Installation

### 1. Create Cluster and Install Cilium

```bash
make up
```

This command:

1. Creates a Kind cluster with CNI disabled
1. Adds Cilium Helm repository
1. Installs Cilium with Hubble enabled

### 2. Verify Installation

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
make down
```
