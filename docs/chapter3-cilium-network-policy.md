# Chapter 3: Cilium Network Policy

Learn Cilium-specific network policies with L7 and DNS controls.

**Official Documentation**: [CiliumNetworkPolicy](https://docs.cilium.io/en/stable/security/policy/) | [L7 Policy](https://docs.cilium.io/en/stable/security/policy/language/#layer-7-examples)

## CiliumNetworkPolicy vs NetworkPolicy

| Feature         | NetworkPolicy | CiliumNetworkPolicy |
| --------------- | ------------- | ------------------- |
| L3/L4 (IP/Port) | Yes           | Yes                 |
| L7 (HTTP/gRPC)  | No            | Yes                 |
| DNS-based rules | No            | Yes                 |
| FQDN matching   | No            | Yes                 |

## 1. L7 HTTP Policy

### Apply L7 Policy

This policy allows only `GET /get` and `GET /headers`:

```bash
kubectl apply -f manifests/cilium-policies/l7-http-policy.yaml
```

See [l7-http-policy.yaml](../manifests/cilium-policies/l7-http-policy.yaml) for details.

### Test Allowed Requests

```bash
# GET /get - should succeed
 ❯ kubectl exec -n demo client -- curl -s backend/get
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "backend",
    "User-Agent": "curl/8.17.0",
    "X-Envoy-Expected-Rq-Timeout-Ms": "3600000",
    "X-Envoy-Internal": "true"
  },
  "origin": "10.0.2.191",
  "url": "http://backend/get"
}

# GET /headers - should succeed
 ❯ kubectl exec -n demo client -- curl -s backend/headers
{
  "headers": {
    "Accept": "*/*",
    "Host": "backend",
    "User-Agent": "curl/8.17.0",
    "X-Envoy-Expected-Rq-Timeout-Ms": "3600000",
    "X-Envoy-Internal": "true"
  }
}
```

### Test Blocked Requests

```bash
# POST /post - should be blocked
 ❯ kubectl exec -n demo client -- curl -s -X POST backend/post -d "key=value"
Access denied

# GET /ip - should be blocked
 ❯ kubectl exec -n demo client -- curl -s backend/ip
Access denied
```

### Check with Hubble

```bash
 ❯ hubble observe -n demo --verdict DROPPED
Jan  3 07:31:03.942: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) policy-verdict:none INGRESS DENIED (TCP Flags: SYN)
Jan  3 07:31:03.942: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) Policy denied DROPPED (TCP Flags: SYN)
Jan  3 07:31:04.991: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) policy-verdict:none INGRESS DENIED (TCP Flags: SYN)
Jan  3 07:31:04.991: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) Policy denied DROPPED (TCP Flags: SYN)
Jan  3 07:31:06.015: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) policy-verdict:none INGRESS DENIED (TCP Flags: SYN)
Jan  3 07:31:06.015: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) Policy denied DROPPED (TCP Flags: SYN)
Jan  3 07:31:07.039: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) policy-verdict:none INGRESS DENIED (TCP Flags: SYN)
Jan  3 07:31:07.039: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) Policy denied DROPPED (TCP Flags: SYN)
Jan  3 07:31:08.062: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) policy-verdict:none INGRESS DENIED (TCP Flags: SYN)
Jan  3 07:31:08.062: demo/client:49358 (ID:22917) <> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) Policy denied DROPPED (TCP Flags: SYN)
Jan  3 07:35:13.180: demo/client:41222 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) http-request DROPPED (HTTP/1.1 POST http://backend/post)
Jan  3 07:35:26.021: demo/client:41870 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) http-request DROPPED (HTTP/1.1 GET http://backend/ip)
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
```

You should see `DROPPED` for blocked HTTP requests.

### Cleanup

```bash
kubectl delete -f manifests/cilium-policies/l7-http-policy.yaml
```

## 2. DNS Policy

### Apply DNS Policy

This policy controls DNS resolution and allows only specific FQDNs:

```bash
kubectl apply -f manifests/cilium-policies/dns-policy.yaml
```

See [dns-policy.yaml](../manifests/cilium-policies/dns-policy.yaml) for details.

### Test DNS Resolution

```bash
# Internal DNS - should succeed
 ❯ kubectl exec -n demo client -- nslookup backend.demo.svc.cluster.local
Server:         10.96.0.10
Address:        10.96.0.10:53


Name:   backend.demo.svc.cluster.local
Address: 10.96.19.174

# External FQDN (httpbin.org) - should succeed
 ❯ kubectl exec -n demo client -- curl -s https://httpbin.org/get
command terminated with exit code 6
```

### Cleanup

```bash
kubectl delete -f manifests/cilium-policies/dns-policy.yaml
```

## Summary

In this chapter, you learned:

- Difference between NetworkPolicy and CiliumNetworkPolicy
- How to control HTTP methods and paths with L7 policy
- How to use DNS-based policies for FQDN matching

Next: [Chapter 4 - Hubble Deep Dive](./chapter4-hubble.md)
