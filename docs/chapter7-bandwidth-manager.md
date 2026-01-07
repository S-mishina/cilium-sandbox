# Chapter 7: Bandwidth Manager

Learn about Cilium's Bandwidth Manager for controlling pod bandwidth.

**Official Documentation**: [Bandwidth Manager](https://docs.cilium.io/en/stable/network/kubernetes/bandwidth-manager/)

## Overview

Bandwidth Manager allows you to limit the network bandwidth of pods using Kubernetes annotations. Cilium implements this using eBPF for efficient, kernel-level rate limiting.

**Use cases:**

- Prevent noisy neighbors from consuming all bandwidth
- Fair resource sharing in multi-tenant environments
- Cost control for cloud egress bandwidth

## Platform Differences

| Item                | Kind                         | Minikube               |
| ------------------- | ---------------------------- | ---------------------- |
| BandwidthManager    | Disabled (procfs limitation) | Enabled (EDT with BPF) |
| Cross-node limiting | N/A                          | Works                  |
| Same-node limiting  | N/A                          | Does not work          |

## Kind Limitation

> **Note**: Bandwidth Manager **does not work in Kind clusters**. The BPF bandwidth manager requires access to kernel procfs paths (`/proc/sys/net/core/default_qdisc`) that are not available in Docker-based Kind nodes.

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

## Minikube

Bandwidth Manager works on Minikube because minikube uses real VMs with full kernel access.

### 1. Verify Bandwidth Manager is Enabled

```bash
 ❯ kubectl exec -n kube-system ds/cilium -- cilium-dbg status --verbose | grep BandwidthManager
BandwidthManager:       EDT with BPF [CUBIC] [eth0]
```

- **EDT** (Earliest Departure Time) - packet scheduling
- **BPF** - implemented with eBPF
- **CUBIC** - congestion control algorithm

### 2. Deploy Test Pods

Deploy iperf3 server on a specific node:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: iperf3-server-m02
  namespace: demo
  labels:
    app: iperf3-server-m02
spec:
  nodeSelector:
    kubernetes.io/hostname: cilium-lab-m02
  containers:
    - name: iperf3
      image: networkstatic/iperf3
      args: ["-s"]
      ports:
        - containerPort: 5201
EOF
```

Deploy bandwidth-limited client on a **different node**:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: limited-client
  namespace: demo
  labels:
    app: limited-client
  annotations:
    kubernetes.io/egress-bandwidth: "1M"
    kubernetes.io/ingress-bandwidth: "1M"
spec:
  nodeSelector:
    kubernetes.io/hostname: cilium-lab-m03
  containers:
    - name: iperf3
      image: networkstatic/iperf3
      command: ["sleep", "infinity"]
EOF
```

> **Important**: Client and server must be on **different nodes** for bandwidth limiting to work.

### 3. Test Bandwidth Limiting

```bash
IPERF_IP=$(kubectl get pod -n demo iperf3-server-m02 -o jsonpath='{.status.podIP}')
kubectl exec -n demo limited-client -- iperf3 -c $IPERF_IP -t 5
```

Expected output (~1 Mbits/sec):

```bash
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   265 KBytes  2.17 Mbits/sec    0   28.7 KBytes
[  5]   1.00-2.00   sec   126 KBytes  1.03 Mbits/sec    0   28.7 KBytes
[  5]   2.00-3.00   sec   126 KBytes  1.03 Mbits/sec    0   28.7 KBytes
[  5]   3.00-4.00   sec  62.8 KBytes   514 Kbits/sec    0   28.7 KBytes
[  5]   4.00-5.00   sec   126 KBytes  1.03 Mbits/sec    0   28.7 KBytes
- - - - - - - - - - - - - - - - - - - - - - - - -
[ ID] Interval           Transfer     Bitrate         Retr
[  5]   0.00-5.00   sec   704 KBytes  1.15 Mbits/sec    0             sender
[  5]   0.00-5.04   sec   587 KBytes   955 Kbits/sec                  receiver
```

### Same-Node Traffic (Not Limited)

If both pods are on the same node, bandwidth limiting does **not** apply:

```bash
# Both pods on same node = no limit
[ ID] Interval           Transfer     Bitrate
[  5]   0.00-5.00   sec  78.4 GBytes   135 Gbits/sec
```

This is expected behavior - Cilium's EDT/BPF rate limiting only applies to traffic leaving the node.

## Pod Annotations

To limit a pod's bandwidth, add these annotations:

```yaml
annotations:
  kubernetes.io/egress-bandwidth: "1M"   # 1 Mbit/s egress limit
  kubernetes.io/ingress-bandwidth: "1M"  # 1 Mbit/s ingress limit
```

Valid suffixes: `K` (kilobits), `M` (megabits), `G` (gigabits)

## Cleanup

```bash
kubectl delete pod -n demo limited-client iperf3-server-m02
```

## Summary

In this chapter, you learned:

- Bandwidth Manager uses eBPF and EDT for kernel-level rate limiting
- **Kind clusters cannot use Bandwidth Manager** due to procfs limitations
- **Minikube supports Bandwidth Manager** with real VM nodes
- Bandwidth limiting only works for **cross-node traffic**, not same-node traffic
- How to configure bandwidth limits using Kubernetes annotations

Next: Chapter 8 (Coming Soon)
