# Chapter 4: Ingress / Gateway API

Learn how to expose services externally using Cilium Ingress Controller and Gateway API.

**Official Documentation**: [Ingress Controller](https://docs.cilium.io/en/stable/network/servicemesh/ingress/) | [Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)

> **Note**: If you ran `make up`, Ingress Controller and Gateway API are already enabled. You can skip the enable steps and go directly to deploying resources.

## Platform Differences

| Item             | Kind                             | Minikube                    |
| ---------------- | -------------------------------- | --------------------------- |
| Ingress HTTP     | `localhost:40000`                | `<NODE_IP>:30000`           |
| Ingress HTTPS    | `localhost:30443` (port-forward) | `<NODE_IP>:30443`           |
| Gateway API mode | hostNetwork (port 30001)         | NodePort (dynamic port)     |
| Gateway access   | `localhost:40001`                | `<NODE_IP>:<NodePort>`      |
| Get Node IP      | N/A                              | `minikube ip -p cilium-lab` |

### Minikube: Get Node IP

```bash
# Get node IP
NODE_IP=$(minikube ip -p cilium-lab)
echo $NODE_IP
```

## 1. Verify Cilium Ingress Controller

Ingress Controller is enabled by default with `make up`. Verify IngressClass is available:

```bash
 ❯ kubectl get ingressclass
NAME     CONTROLLER                     PARAMETERS   AGE
cilium   cilium.io/ingress-controller   <none>       5m19s
```

## 2. Deploy Ingress

Apply basic Ingress:

```bash
kubectl apply -f manifests/ingress/basic-ingress.yaml
```

See [basic-ingress.yaml](../manifests/ingress/basic-ingress.yaml) for details.

Check Ingress status:

```bash
 ❯ kubectl get ingress -n demo
NAME              CLASS    HOSTS   ADDRESS   PORTS   AGE
backend-ingress   cilium   *                 80      5s
```

Test access:

```bash
# Kind
curl -s http://localhost:40000/get

# Minikube
NODE_IP=$(minikube ip -p cilium-lab)
curl -s http://${NODE_IP}:30000/get
```

Example output (Kind):

```bash
 ❯ curl -s http://localhost:40000/get -v
* Host localhost:40000 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:40000...
* connect to ::1 port 40000 from ::1 port 51106 failed: Connection refused
*   Trying 127.0.0.1:40000...
* Connected to localhost (127.0.0.1) port 40000
> GET /get HTTP/1.1
> Host: localhost:40000
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< server: envoy
< date: Sat, 03 Jan 2026 08:07:07 GMT
< content-type: application/json
< content-length: 245
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 1
<
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "localhost:40000",
    "User-Agent": "curl/8.7.1",
    "X-Envoy-External-Address": "162.247.243.27"
  },
  "origin": "162.247.243.27",
  "url": "http://localhost:40000/get"
}
* Connection #0 to host localhost left intact
```

## 3. Gateway API

Gateway API is the next generation of Ingress, providing more features and flexibility.

### Platform-specific Notes

- **Kind**: Uses **hostNetwork mode**. The Gateway listener port (30001) is directly exposed on all nodes, accessible at `localhost:40001` via Kind port mappings.
- **Minikube**: Uses **NodePort mode** with custom GatewayClass. Access via `<NODE_IP>:<NodePort>`.

### Verify Gateway API

Gateway API is enabled by default with `make up`. Verify GatewayClass is available:

```bash
 ❯ kubectl get gatewayclass
NAME     CONTROLLER                     ACCEPTED   AGE
cilium   io.cilium/gateway-controller   True       5m8s
```

For Minikube, you'll also see a custom NodePort GatewayClass:

```bash
 ❯ kubectl get gatewayclass
NAME              CONTROLLER                     ACCEPTED   AGE
cilium            io.cilium/gateway-controller   True       5m
cilium-nodeport   io.cilium/gateway-controller   False      5m
```

> **Note**: `cilium-nodeport` may show `ACCEPTED: False` due to a [known Cilium bug](https://github.com/cilium/cilium/issues/42956), but it still functions correctly.

### Deploy Gateway and HTTPRoute

```bash
# Kind
kubectl apply -f manifests/ingress/gateway.yaml

# Minikube
kubectl apply -f manifests/ingress/gateway-class-config.yaml
kubectl apply -f overlays/minikube/gateway.yaml
kubectl apply -f manifests/ingress/httproute.yaml
```

See [gateway.yaml](../manifests/ingress/gateway.yaml) (Kind) or [overlays/minikube/gateway.yaml](../overlays/minikube/gateway.yaml) (Minikube) for details.

Check Gateway status:

```bash
# Kind
 ❯ kubectl get gateway -n demo
NAME             CLASS    ADDRESS   PROGRAMMED   AGE
cilium-gateway   cilium             True         5m

# Minikube
 ❯ kubectl get gateway -n demo
NAME             CLASS             ADDRESS   PROGRAMMED   AGE
cilium-gateway   cilium-nodeport             False        5m

 ❯ kubectl get httproute -n demo
NAME            HOSTNAMES   AGE
backend-route               5m11s
```

For Minikube, check the Gateway Service NodePort:

```bash
 ❯ kubectl get svc -n demo cilium-gateway-cilium-gateway
NAME                            TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
cilium-gateway-cilium-gateway   NodePort   10.96.103.178   <none>        80:30374/TCP   5m
```

Test access:

```bash
# Kind
curl -s http://localhost:40001/get

# Minikube
NODE_IP=$(minikube ip -p cilium-lab)
NODE_PORT=$(kubectl get svc -n demo cilium-gateway-cilium-gateway -o jsonpath='{.spec.ports[0].nodePort}')
curl -s http://${NODE_IP}:${NODE_PORT}/get
```

Example output (Kind):

```bash
 ❯ curl -s http://localhost:40001/get -v
* Host localhost:40001 was resolved.
* IPv6: ::1
* IPv4: 127.0.0.1
*   Trying [::1]:40001...
* connect to ::1 port 40001 from ::1 port 50451 failed: Connection refused
*   Trying 127.0.0.1:40001...
* Connected to localhost (127.0.0.1) port 40001
> GET /get HTTP/1.1
> Host: localhost:40001
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< server: envoy
< date: Sat, 03 Jan 2026 11:12:06 GMT
< content-type: application/json
< content-length: 245
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 1
<
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "localhost:40001",
    "User-Agent": "curl/8.7.1",
    "X-Envoy-External-Address": "172.105.192.74"
  },
  "origin": "172.105.192.74",
  "url": "http://localhost:40001/get"
}
* Connection #0 to host localhost left intact
```

## 4. TLS Termination

### Generate Self-Signed Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=backend.local"
```

### Create TLS Secret

```bash
kubectl create secret tls backend-tls -n demo --cert=tls.crt --key=tls.key
```

### Apply TLS Ingress

```bash
kubectl apply -f manifests/ingress/tls-ingress.yaml
```

See [tls-ingress.yaml](../manifests/ingress/tls-ingress.yaml) for details.

Test access:

```bash
# Kind
curl --resolve backend.local:30443:127.0.0.1 -sk https://backend.local:30443/get

# Minikube
NODE_IP=$(minikube ip -p cilium-lab)
curl --resolve backend.local:30443:${NODE_IP} -sk https://backend.local:30443/get
```

Example output (Kind):

```bash
 ❯ curl --resolve backend.local:30443:127.0.0.1 -v -sk https://backend.local:30443/get
* Added backend.local:30443:127.0.0.1 to DNS cache
* Hostname backend.local was found in DNS cache
*   Trying 127.0.0.1:30443...
* Connected to backend.local (127.0.0.1) port 30443
* ALPN: curl offers h2,http/1.1
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256 / [blank] / UNDEF
* ALPN: server did not agree on a protocol. Uses default.
* Server certificate:
*  subject: CN=backend.local
*  start date: Jan  4 04:01:28 2026 GMT
*  expire date: Jan  4 04:01:28 2027 GMT
*  issuer: CN=backend.local
*  SSL certificate verify result: self signed certificate (18), continuing anyway.
* using HTTP/1.x
> GET /get HTTP/1.1
> Host: backend.local:30443
> User-Agent: curl/8.7.1
> Accept: */*
>
* Request completely sent off
< HTTP/1.1 200 OK
< server: envoy
< date: Sun, 04 Jan 2026 13:31:14 GMT
< content-type: application/json
< content-length: 254
< access-control-allow-origin: *
< access-control-allow-credentials: true
< x-envoy-upstream-service-time: 1
<
{
  "args": {},
  "headers": {
    "Accept": "*/*",
    "Host": "backend.local:30443",
    "User-Agent": "curl/8.7.1",
    "X-Envoy-External-Address": "172.105.192.74"
  },
  "origin": "172.105.192.74",
  "url": "https://backend.local:30443/get"
}
* Connection #0 to host backend.local left intact
```

## 5. Cleanup

```bash
kubectl delete -f manifests/ingress/
rm -f tls.crt tls.key
```

## Summary

In this chapter, you learned:

- How to enable Cilium Ingress Controller
- How to expose services with Ingress
- How to use Gateway API for advanced routing
- How to configure TLS termination

## Platform Differences Summary

| Item             | Kind                             | Minikube                         |
| ---------------- | -------------------------------- | -------------------------------- |
| Ingress HTTP     | `localhost:40000`                | `<NODE_IP>:30000`                |
| Ingress HTTPS    | `localhost:30443`                | `<NODE_IP>:30443`                |
| Gateway API mode | hostNetwork                      | NodePort                         |
| GatewayClass     | `cilium`                         | `cilium-nodeport`                |
| Gateway access   | `localhost:40001`                | `<NODE_IP>:<NodePort>` (dynamic) |
| Gateway manifest | `manifests/ingress/gateway.yaml` | `overlays/minikube/gateway.yaml` |

> **Known Issue**: Minikube's `cilium-nodeport` GatewayClass shows `ACCEPTED: False` due to a [Cilium bug](https://github.com/cilium/cilium/issues/42956). The Gateway still works correctly.
>
> **Feature Request**: Fixed NodePort for Gateway API is tracked in [CFP #43574](https://github.com/cilium/cilium/issues/43574).

Next: [Chapter 5 - Egress Gateway](./chapter5-egress-gateway.md)
