# Chapter 7: Bandwidth Manager

Learn about Cilium's Bandwidth Manager for controlling pod bandwidth.

**Official Documentation**: [Bandwidth Manager](https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager/)

## Overview

Bandwidth Manager allows you to limit the network bandwidth of pods using Kubernetes annotations. Cilium implements this using eBPF for efficient, kernel-level rate limiting.

**Use cases:**

- Prevent noisy neighbors from consuming all bandwidth
- Fair resource sharing in multi-tenant environments
- Cost control for cloud egress bandwidth

## kind Limitation

> **Note**: Bandwidth Manager **does not work in kind clusters**. The BPF bandwidth manager requires access to kernel procfs paths (`/proc/sys/net/core/default_qdisc`) that are not available in Docker-based kind nodes.

You can verify this by checking the Cilium logs:

```bash
❯ kubectl logs -n kube-system ds/cilium | grep -i bandwidth
level=warn msg="BPF bandwidth manager could not read procfs. Disabling the feature."
```

And checking the status:

```bash
❯ kubectl exec -n kube-system ds/cilium -- cilium-dbg status --verbose | grep BandwidthManager
BandwidthManager:       Disabled
```

## How It Works (Production)

In a production environment with real nodes (not containerized), Bandwidth Manager:

1. Uses eBPF and EDT (Earliest Departure Time) for rate limiting
1. Applies limits via Kubernetes annotations on pods
1. Provides both ingress and egress bandwidth control

### Configuration

Bandwidth Manager is enabled in `base/cilium/values.yaml`:

```yaml
bandwidthManager:
  enabled: true
```

### Pod Annotations

To limit a pod's bandwidth, add these annotations:

```yaml
annotations:
  kubernetes.io/egress-bandwidth: "1M"   # 1 Mbit/s egress limit
  kubernetes.io/ingress-bandwidth: "1M"  # 1 Mbit/s ingress limit
```

Valid suffixes: `K` (kilobits), `M` (megabits), `G` (gigabits)

### Example Manifest

See [limited-client.yaml](../manifests/bandwidth/limited-client.yaml):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: limited-client
  namespace: demo
  annotations:
    kubernetes.io/egress-bandwidth: "1M"
    kubernetes.io/ingress-bandwidth: "1M"
spec:
  containers:
    - name: iperf3
      image: networkstatic/iperf3
      command: ["sleep", "infinity"]
```

## Testing in Production

On a real Kubernetes cluster (not kind), you can test bandwidth limiting:

```bash
# Deploy iperf3 server (already included in demo-pods.yaml)
# Deploy limited client
kubectl apply -f manifests/bandwidth/limited-client.yaml

# Get iperf3 server IP
IPERF_IP=$(kubectl get pod -n demo iperf3-server -o jsonpath='{.status.podIP}')

# Test bandwidth (should be limited to ~1 Mbps)
kubectl exec -n demo limited-client -- iperf3 -c $IPERF_IP -t 5
```

Expected output with working Bandwidth Manager:

```
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-5.00   sec   625 KBytes  1.00 Mbits/sec
```

## Summary

In this chapter, you learned:

- Bandwidth Manager uses eBPF for kernel-level rate limiting
- **kind clusters cannot use Bandwidth Manager** due to procfs limitations
- How to configure bandwidth limits using Kubernetes annotations
- The feature works on production clusters with real nodes

Next: Chapter 8 (Coming Soon)
