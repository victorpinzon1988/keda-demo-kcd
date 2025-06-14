#!/usr/bin/env bash
set -euo pipefail

# 0. Helm
if ! command -v helm &>/dev/null; then
  curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# 1. Minikube
if ! minikube status -p keda-demo &>/dev/null; then
  minikube start -p keda-demo --memory 4096 --cpus 4 --driver=docker
fi

# 2. Repos Helm
helm repo add kedacore https://kedacore.github.io/charts || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

# 3. KEDA
kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install keda kedacore/keda -n keda

# 4. kube‑prometheus‑stack (consola Prometheus + CRDs)
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack -n monitoring \
  --set grafana.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "🎉 Entorno listo. Construye la imagen y despliega la API."