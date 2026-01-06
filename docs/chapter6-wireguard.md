# Chapter 6: WireGuard Encryption

Learn how Cilium encrypts pod-to-pod traffic using WireGuard.

**Official Documentation**: [WireGuard Encryption](https://docs.cilium.io/en/stable/security/network/encryption-wireguard/)

## Overview

WireGuard is a modern, high-performance VPN protocol built into the Linux kernel. Cilium integrates WireGuard to provide transparent encryption for all pod-to-pod traffic across nodes.

**Benefits:**

- Transparent encryption (no app changes required)
- High performance (kernel-level processing)
- Simple configuration
- Automatic key management

WireGuard is enabled by default with `make up`. This chapter covers how to verify and understand the encryption.

## 1. Verify WireGuard Status

Check encryption status on any Cilium agent:

```bash
 ❯ kubectl exec -n kube-system ds/cilium -- cilium-dbg encrypt status
Encryption: Wireguard
Interface: cilium_wg0
        Public key: uxkNrymMvUi/t/wNh+2Vg6aw7M3gRfIk1u+YdPqwtlU=
        Number of peers: 2
```

Key information:

- `Encryption: Wireguard` - WireGuard is active
- `Interface: cilium_wg0` - WireGuard network interface
- `Number of peers: 2` - Connected to 2 other nodes (worker, worker2, control-plane)

## 2. Check WireGuard Configuration

View the Cilium configuration:

```bash
 ❯ cilium config view | grep -i wire
enable-wireguard                                  true
wireguard-persistent-keepalive                    0s
```

## 3. Test Encrypted Traffic

Demo pods are already deployed by `make up`. Test cross-node connectivity:

```bash
# Get client-worker2 IP
 ❯ TEST_IP=$(kubectl get pod -n demo client-worker2 -o jsonpath='{.status.podIP}')
 ❯ echo $TEST_IP
10.244.2.244

# Ping from client-worker to client-worker2 (cross-node, encrypted)
 ❯ kubectl exec -n demo client-worker -- ping -c 3 $TEST_IP
PING 10.244.2.244 (10.244.2.244): 56 data bytes
64 bytes from 10.244.2.244: seq=0 ttl=42 time=0.352 ms
64 bytes from 10.244.2.244: seq=1 ttl=42 time=0.919 ms
64 bytes from 10.244.2.244: seq=2 ttl=42 time=0.484 ms

--- 10.244.2.244 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.352/0.585/0.919 ms
```

## 4. Verify Encryption is Active

Confirm encryption status after the ping test:

```bash
 ❯ kubectl exec -n kube-system ds/cilium -- cilium-dbg encrypt status
Encryption: Wireguard
Interface: cilium_wg0
        Public key: uxkNrymMvUi/t/wNh+2Vg6aw7M3gRfIk1u+YdPqwtlU=
        Number of peers: 2
```

`Number of peers: 2` confirms encrypted tunnels are established between nodes.

## 5. How It Works

```
┌─────────────────┐                    ┌─────────────────┐
│  cilium-lab-    │                    │  cilium-lab-    │
│  worker         │                    │  worker2        │
│                 │                    │                 │
│  ┌───────────┐  │   WireGuard        │  ┌───────────┐  │
│  │ client-   │  │   encrypted        │  │ client-   │  │
│  │ worker    │──┼────────────────────┼──│ worker2   │  │
│  └───────────┘  │   tunnel           │  └───────────┘  │
│                 │                    │                 │
│  cilium_wg0     │◄──────────────────►│  cilium_wg0     │
└─────────────────┘                    └─────────────────┘
```

- Each node has a `cilium_wg0` interface
- Cilium automatically manages WireGuard keys
- All cross-node pod traffic is encrypted transparently

## Summary

In this chapter, you learned:

- WireGuard is enabled by default in this sandbox
- How to verify WireGuard encryption status
- How to check WireGuard interface and peer information
- How cross-node pod traffic is transparently encrypted

Next: [Chapter 7 - Bandwidth Manager](./chapter7-bandwidth-manager.md)
