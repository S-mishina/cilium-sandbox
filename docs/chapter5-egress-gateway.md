# Chapter 5: Egress Gateway

Learn how to control outbound traffic using Cilium Egress Gateway.

**Official Documentation**: [Egress Gateway](https://docs.cilium.io/en/stable/network/egress-gateway/)

## Overview

Egress Gateway allows you to:

- Route egress traffic through specific gateway nodes
- Assign a fixed source IP for outbound traffic
- Monitor and control egress traffic from pods

This is useful for:

- Firewall rules that require fixed source IPs
- Compliance requirements for outbound traffic
- Network topology control

> **Kind Limitation**: In Kind environments, the egress gateway node must be the same node as the client pod. This is because all Kind nodes share the same Docker network, causing asymmetric routing when traffic returns via a different path. This sandbox uses per-node policies with Kyverno to automatically label pods based on their `nodeSelector`.

## 1. Verify Egress Gateway

Egress Gateway is enabled by default with `make up`. Verify it's enabled:

```bash
 ❯ cilium config view | grep egress
egress-gateway-reconciliation-trigger-interval    1s
enable-egress-gateway                             true
proxy-xff-num-trusted-hops-egress                 0
```

## 2. Deploy Egress Gateway Policy

Apply the Egress Gateway Policies (per-node approach for Kind):

```bash
kubectl apply -f manifests/egress/egress-gateway-policy.yaml
```

See [egress-gateway-policy.yaml](../manifests/egress/egress-gateway-policy.yaml) for details. The manifest contains three policies—one for each node. Each policy uses `podSelector` with a `node` label to match only pods on that specific node.

Check the policies:

```bash
 ❯ kubectl get ciliumegressgatewaypolicies
NAME                   AGE
egress-control-plane   5m
egress-worker          5m
egress-worker2         5m
```

## 3. Create a Pod with nodeSelector

Kyverno automatically adds the `node` label based on `nodeSelector`. Create a pod with `nodeSelector`:

```bash
kubectl run client -n demo --image=curlimages/curl --labels="app=client" \
  --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"cilium-lab-worker"}}}' \
  --command -- sleep infinity
```

Verify the label was added automatically by Kyverno:

```bash
 ❯ kubectl get pod -n demo client --show-labels
NAME     READY   STATUS    RESTARTS   AGE   LABELS
client   1/1     Running   0          10s   app=client,node=cilium-lab-worker
```

Verify BPF egress entries (Gateway IP should match the pod's node):

```bash
 ❯ kubectl exec -n kube-system daemonset/cilium -- cilium-dbg bpf egress list
Source IP     Destination CIDR   Egress IP     Gateway IP
10.244.1.26   10.96.0.0/16       172.19.0.11   Excluded CIDR
10.244.1.26   10.244.0.0/16      172.19.0.11   Excluded CIDR
10.244.1.26   172.19.0.0/16      172.19.0.11   Excluded CIDR
10.244.1.26   0.0.0.0/0          172.19.0.11   172.19.0.11
```

## 4. Test Egress Gateway

Test egress traffic from the client pod:

```bash
 ❯ kubectl exec -n demo client -- curl -s https://ifconfig.me
123.218.107.11%
```

## 5. Verify with Hubble

Monitor egress traffic with Hubble:

```bash
 ❯ hubble observe --to-fqdn ifconfig.me
rpc error: code = Unavailable desc = connection error: desc = "error reading server preface: read tcp 127.0.0.1:55352->127.0.0.1:4245: read: connection reset by peer"
```

Or use Hubble UI:

```bash
cilium hubble ui
```

## 6. Advanced: Egress IP Assignment

You can assign a specific egress IP instead of using the node's IP:

```yaml
apiVersion: cilium.io/v2
kind: CiliumEgressGatewayPolicy
metadata:
  name: fixed-ip-egress
spec:
  selectors:
    - podSelector:
        matchLabels:
          app: client
  destinationCIDRs:
    - "0.0.0.0/0"
  egressGateway:
    nodeSelector:
      matchLabels:
        kubernetes.io/hostname: cilium-lab-worker
    egressIP: 192.168.1.100  # Fixed egress IP
```

> **Note**: The egress IP must be routable from the gateway node.

## 7. Cleanup

```bash
kubectl delete -f manifests/egress/
```

## Summary

In this chapter, you learned:

- How to verify Egress Gateway is enabled
- How to create per-node Egress Gateway Policies for Kind
- How Kyverno automatically labels pods based on nodeSelector
- How to verify egress traffic routing
- How to use fixed egress IPs

Next: [Chapter 6 - WireGuard Encryption](./chapter6-wireguard.md)
