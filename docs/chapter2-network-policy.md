# Chapter 2: Network Policy

Learn how to control traffic with Kubernetes NetworkPolicy.

**Official Documentation**: [Network Policy](https://docs.cilium.io/en/stable/security/policy/language/#layer-3-examples)

## 1. Verify Current State (No Policy)

First, confirm that all traffic is allowed:

```bash
 ❯ kubectl exec -n demo client -- curl -s backend/get
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "backend",
    "User-Agent": "curl/8.17.0"
  },
  "origin": "10.0.2.196",
  "url": "http://backend/get"
}
```

This should succeed.

Check with Hubble:

```bash
 ❯ hubble observe -n demo --last 5
Jan  3 07:30:14.821: demo/client:57767 (ID:22917) -> kube-system/coredns-7d764666f9-jbn7k:53 (ID:7909) to-endpoint FORWARDED (UDP)
Jan  3 07:30:14.821: demo/client:57767 (ID:22917) <> kube-system/coredns-7d764666f9-jbn7k (ID:7909) pre-xlate-rev TRACED (UDP)
Jan  3 07:30:14.821: demo/client:57767 (ID:22917) <> kube-system/coredns-7d764666f9-jbn7k (ID:7909) pre-xlate-rev TRACED (UDP)
Jan  3 07:30:14.821: demo/client:57767 (ID:22917) <- kube-system/coredns-7d764666f9-jbn7k:53 (ID:7909) to-overlay FORWARDED (UDP)
Jan  3 07:30:14.824: demo/client:60186 (ID:22917) <> demo/backend-657df4f9d8-sh6lt (ID:40767) pre-xlate-rev TRACED (TCP)
Jan  3 07:30:14.828: demo/client:60186 (ID:22917) <- demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, PSH)
Jan  3 07:30:14.828: demo/client:60186 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, FIN)
Jan  3 07:30:14.828: demo/client:60186 (ID:22917) <- demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, FIN)
Jan  3 07:30:14.828: demo/client:60186 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK)
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
```

All traffic shows `FORWARDED`.

## 2. Apply Default Deny Policy

Create a policy that denies all ingress traffic to backend:

```bash
kubectl apply -f manifests/network-policies/deny-all-ingress.yaml
```

See [deny-all-ingress.yaml](../manifests/network-policies/deny-all-ingress.yaml) for details.

## 3. Verify Traffic is Blocked

Try the same request:

```bash
 ❯ kubectl exec -n demo client -- curl -s --max-time 5 backend/get
command terminated with exit code 28
```

This should timeout.

Check with Hubble:

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
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
EVENTS LOST: HUBBLE_RING_BUFFER CPU(0) 1
```

You should see `DROPPED` flows.

## 4. Allow Traffic from Client

Add a policy to allow traffic from client:

```bash
kubectl apply -f manifests/network-policies/allow-client-to-backend.yaml
```

See [allow-client-to-backend.yaml](../manifests/network-policies/allow-client-to-backend.yaml) for details.

## 5. Verify Traffic is Restored

```bash
 ❯ kubectl exec -n demo client -- curl -s backend/get
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "backend",
    "User-Agent": "curl/8.17.0"
  },
  "origin": "10.0.2.196",
  "url": "http://backend/get"
}
```

This should succeed again.

Check with Hubble:

```bash
 ❯ hubble observe -n demo --last 5
Jan  3 07:31:03.942: demo/client:34785 (ID:22917) <- kube-system/coredns-7d764666f9-4t6zl:53 (ID:7909) to-overlay FORWARDED (UDP)
Jan  3 07:32:14.750: demo/client:51083 (ID:22917) -> kube-system/coredns-7d764666f9-4t6zl:53 (ID:7909) to-endpoint FORWARDED (UDP)
Jan  3 07:32:14.750: demo/client:51083 (ID:22917) <> kube-system/coredns-7d764666f9-4t6zl (ID:7909) pre-xlate-rev TRACED (UDP)
Jan  3 07:32:14.750: demo/client:51083 (ID:22917) <> kube-system/coredns-7d764666f9-4t6zl (ID:7909) pre-xlate-rev TRACED (UDP)
Jan  3 07:32:14.750: demo/client:51083 (ID:22917) <- kube-system/coredns-7d764666f9-4t6zl:53 (ID:7909) to-overlay FORWARDED (UDP)
Jan  3 07:32:14.751: demo/client:58236 (ID:22917) <> demo/backend-657df4f9d8-sh6lt (ID:40767) pre-xlate-rev TRACED (TCP)
Jan  3 07:32:14.752: demo/client:58236 (ID:22917) <- demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, PSH)
Jan  3 07:32:14.752: demo/client:58236 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, FIN)
Jan  3 07:32:14.752: demo/client:58236 (ID:22917) <- demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK, FIN)
Jan  3 07:32:14.752: demo/client:58236 (ID:22917) -> demo/backend-657df4f9d8-sh6lt:80 (ID:40767) to-endpoint FORWARDED (TCP Flags: ACK)
```

Traffic shows `FORWARDED` again.

## 6. Cleanup

Remove the policies:

```bash
kubectl delete -f manifests/network-policies/
```

## Summary

In this chapter, you learned:

- How to apply a default deny policy
- How to verify blocked traffic with Hubble
- How to allow specific traffic with NetworkPolicy

Next: [Chapter 3 - Cilium Network Policy](./chapter3-cilium-network-policy.md)
