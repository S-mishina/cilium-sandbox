.PHONY: help kind-create kind-delete minikube-create minikube-delete bootpd-enable bootpd-disable cilium-install cilium-status coredns-config clean

CLUSTER_NAME ?= cilium-lab
KIND_CONFIG := kind-config.yaml
MINIKUBE_CONFIG := minikube-config.yaml
MINIKUBE_DRIVER := $(shell yq '.driver' $(MINIKUBE_CONFIG))
MINIKUBE_NETWORK := $(shell yq '.network' $(MINIKUBE_CONFIG))
MINIKUBE_NODES := $(shell yq '.nodes' $(MINIKUBE_CONFIG))
MINIKUBE_CPUS := $(shell yq '.cpus' $(MINIKUBE_CONFIG))
MINIKUBE_MEMORY := $(shell yq '.memory' $(MINIKUBE_CONFIG))
MINIKUBE_K8S_VERSION := $(shell yq '.["kubernetes-version"]' $(MINIKUBE_CONFIG))
OVERLAY ?= kind

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'

# =============================================================================
# Kind Cluster
# =============================================================================

kind-create: ## Create kind cluster for Cilium
	kind create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)
	@echo "Kind cluster $(CLUSTER_NAME) created!"

kind-delete: ## Delete kind cluster
	kind delete cluster --name $(CLUSTER_NAME)

# =============================================================================
# Minikube Cluster
# =============================================================================

bootpd-enable: ## Enable bootpd in firewall (required for socket_vmnet)
	@echo "Enabling bootpd in firewall..."
	sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/libexec/bootpd
	sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /usr/libexec/bootpd
	@echo "bootpd enabled!"

bootpd-disable: ## Disable bootpd in firewall
	@echo "Disabling bootpd in firewall..."
	sudo /usr/libexec/ApplicationFirewall/socketfilterfw --remove /usr/libexec/bootpd
	@echo "bootpd removed from firewall!"

minikube-create: ## Create minikube cluster for Cilium (VM driver)
	minikube start \
		--driver=$(MINIKUBE_DRIVER) \
		--network=$(MINIKUBE_NETWORK) \
		--nodes=$(MINIKUBE_NODES) \
		--cpus=$(MINIKUBE_CPUS) \
		--memory=$(MINIKUBE_MEMORY) \
		--kubernetes-version=$(MINIKUBE_K8S_VERSION) \
		--cni=false \
		--network-plugin=cni \
		--profile=$(CLUSTER_NAME)
	@echo "Minikube cluster $(CLUSTER_NAME) created!"

minikube-delete: ## Delete minikube cluster
	minikube delete --profile=$(CLUSTER_NAME)

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

cilium-install: cilium-repo gateway-crds ## Install Cilium via Helm (use OVERLAY=kind or OVERLAY=minikube)
	helm install cilium cilium/cilium --version 1.18.5 \
		--namespace kube-system \
		-f overlays/$(OVERLAY)/cilium-values.yaml
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

cilium-upgrade: ## Upgrade Cilium with values.yaml (use OVERLAY=kind or OVERLAY=minikube)
	helm upgrade cilium cilium/cilium --version 1.18.5 \
		--namespace kube-system \
		-f overlays/$(OVERLAY)/cilium-values.yaml
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
# Kyverno / Demo Pods
# =============================================================================

kyverno-install: ## Install Kyverno for policy management
	helm repo add kyverno https://kyverno.github.io/kyverno/ || true
	helm repo update
	helm install kyverno kyverno/kyverno -n kyverno --create-namespace -f base/kyverno/values.yaml
	kubectl rollout status deployment/kyverno-admission-controller -n kyverno --timeout=300s
	kubectl apply -f base/kyverno/node-label-policy.yaml
	@echo "Kyverno installed with node-label policy!"

demo-pods: ## Deploy demo client pods on each node (use OVERLAY=kind or OVERLAY=minikube)
ifeq ($(OVERLAY),minikube)
	kubectl apply -k overlays/minikube
else
	kubectl apply -f manifests/demo/demo-pods.yaml
endif
	kubectl wait --for=condition=Ready pod -l app=client -n demo --timeout=60s
	@echo "Demo pods ready!"

# =============================================================================
# All-in-one (Kind)
# =============================================================================

kind-up: kind-create ## Create kind cluster + Install Cilium + Kyverno + Demo pods
	$(MAKE) cilium-install OVERLAY=kind
	$(MAKE) coredns-config
	$(MAKE) kyverno-install
	$(MAKE) demo-pods OVERLAY=kind
	@echo "Kind Cilium lab is ready!"

kind-down: kind-delete ## Delete kind cluster
	@echo "Kind cluster deleted"

# =============================================================================
# All-in-one (Minikube)
# =============================================================================

minikube-up: bootpd-enable minikube-create ## Create minikube cluster + Install Cilium + Kyverno + Demo pods
	$(MAKE) cilium-install OVERLAY=minikube
	$(MAKE) kyverno-install
	$(MAKE) demo-pods OVERLAY=minikube
	@echo "Minikube Cilium lab is ready!"

minikube-down: minikube-delete bootpd-disable ## Delete minikube cluster
	@echo "Minikube cluster deleted"

# =============================================================================
# Legacy aliases (backward compatibility)
# =============================================================================

cluster-create: kind-create ## (Alias) Create kind cluster
cluster-delete: kind-delete ## (Alias) Delete kind cluster
up: kind-up ## (Alias) Same as kind-up
down: kind-down ## (Alias) Same as kind-down
