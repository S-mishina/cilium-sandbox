.PHONY: help cluster-create cluster-delete cilium-install cilium-status coredns-config egress-gateway-setup clean

CLUSTER_NAME ?= cilium-lab
KIND_CONFIG := kind-config.yaml
OVERLAY ?= local

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Kind Cluster
# =============================================================================

cluster-create: ## Create kind cluster for Cilium
	kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)
	@echo "Cluster $(CLUSTER_NAME) created!"

cluster-delete: ## Delete kind cluster
	kind delete cluster --name $(CLUSTER_NAME)

# =============================================================================
# Cilium (Helm)
# =============================================================================

cilium-repo: ## Add Cilium Helm repo
	helm repo add cilium https://helm.cilium.io/
	helm repo update

gateway-crds: ## Install Gateway API CRDs
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

cilium-install: cilium-repo gateway-crds ## Install Cilium via Helm
	helm install cilium cilium/cilium --version 1.18.5 \
		--namespace kube-system \
		-f base/cilium/values.yaml
	cilium status --wait
	@echo "Restarting cilium-operator for GatewayClass registration..."
	kubectl rollout restart deployment/cilium-operator -n kube-system
	kubectl rollout status deployment/cilium-operator -n kube-system --timeout=120s
	@echo "Waiting for GatewayClass to be accepted..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		STATUS=$$(kubectl get gatewayclass cilium -o jsonpath='{.status.conditions[?(@.type=="Accepted")].status}' 2>/dev/null); \
		if [ "$$STATUS" = "True" ]; then \
			echo "GatewayClass accepted!"; \
			break; \
		fi; \
		echo "Waiting for GatewayClass... ($$i/10)"; \
		sleep 3; \
	done

cilium-status: ## Check Cilium status
	cilium status

cilium-connectivity-test: ## Run Cilium connectivity test
	cilium connectivity test

# =============================================================================
# Ingress / Gateway API
# =============================================================================

cilium-upgrade: ## Upgrade Cilium with values.yaml
	helm upgrade cilium cilium/cilium --version 1.18.5 \
		--namespace kube-system \
		-f base/cilium/values.yaml
	kubectl rollout restart deployment/cilium-operator -n kube-system
	kubectl rollout status deployment/cilium-operator -n kube-system --timeout=120s
	cilium status --wait

# =============================================================================
# Hubble
# =============================================================================

hubble-ui: ## Open Hubble UI
	cilium hubble ui

# =============================================================================
# Demo Apps
# =============================================================================

demo-deploy: ## Deploy Star Wars demo app
	kubectl create -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/http-sw-app.yaml
	kubectl get pods -w

demo-policy: ## Apply L7 network policy
	kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/sw_l3_l4_l7_policy.yaml

demo-clean: ## Clean up demo app
	kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/http-sw-app.yaml --ignore-not-found
	kubectl delete -f https://raw.githubusercontent.com/cilium/cilium/HEAD/examples/minikube/sw_l3_l4_l7_policy.yaml --ignore-not-found

# =============================================================================
# CoreDNS
# =============================================================================

coredns-config: ## Configure CoreDNS for external DNS (8.8.8.8)
	kubectl apply -f manifests/coredns/coredns-configmap.yaml
	kubectl rollout restart deployment/coredns -n kube-system
	kubectl rollout status deployment/coredns -n kube-system --timeout=60s
	@echo "CoreDNS configured with external DNS (8.8.8.8)"

# =============================================================================
# Egress Gateway
# =============================================================================

kyverno-install: ## Install Kyverno for policy management
	helm repo add kyverno https://kyverno.github.io/kyverno/ || true
	helm repo update
	helm install kyverno kyverno/kyverno -n kyverno --create-namespace -f base/kyverno/values.yaml
	kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=120s
	kubectl apply -f base/kyverno/node-label-policy.yaml
	@echo "Kyverno installed with node-label policy!"

demo-pods: ## Deploy demo client pods on each node
	kubectl apply -f manifests/demo/demo-pods.yaml
	kubectl wait --for=condition=Ready pod -l app=client -n demo --timeout=60s
	@echo "Demo pods ready!"

# =============================================================================
# All-in-one
# =============================================================================

up: cluster-create cilium-install coredns-config kyverno-install demo-pods ## Create cluster + Install Cilium + Kyverno + Demo pods
	@echo "Cilium lab is ready!"

down: cluster-delete ## Delete everything
	@echo "Cluster deleted"
