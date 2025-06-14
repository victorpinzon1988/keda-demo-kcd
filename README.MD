KEDA Demo on Minikube KCD


1 . Helm chart demo-api

1.1 Chart.yaml

apiVersion: v2
name: demo-api
version: 0.2.0
appVersion: "1.0"
description: FastAPI demo que escala con KEDA (Prometheus + CPU)

1.2 values.yaml

nameOverride: ""

image:
  repository: demo-api   # imagen local en Minikube
  tag: latest
  pullPolicy: IfNotPresent

service:
  port: 8000

replicas:
  min: 1
  max: 10

thresholds:
  rps: 5   # req/s
  cpu: 80  # %

cooldown: 60

promStackRelease: kube-prom

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 250m
    memory: 256Mi

1.3 templates/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.nameOverride | default .Release.Name }}
  labels:
    app: {{ .Values.nameOverride | default .Release.Name }}
spec:
  replicas: {{ .Values.replicas.min }}
  selector:
    matchLabels:
      app: {{ .Values.nameOverride | default .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Values.nameOverride | default .Release.Name }}
    spec:
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
          resources:
{{- toYaml .Values.resources | nindent 12 }}

1.4 templates/service.yaml

apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.nameOverride | default .Release.Name }}
  labels:
    app: {{ .Values.nameOverride | default .Release.Name }}
    release: {{ .Values.promStackRelease }}   # Para que el PodMonitor funcione
spec:
  selector:
    app: {{ .Values.nameOverride | default .Release.Name }}
  ports:
    - name: http
      port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP

1.5 templates/podmonitor.yaml  (scrape automático en kube‑prometheus‑stack)

apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: {{ .Values.nameOverride | default .Release.Name }}
  labels:
    release: {{ .Values.promStackRelease }}  # Debe coincidir con el stack Prometheus
spec:
  selector:
    matchLabels:
      app: {{ .Values.nameOverride | default .Release.Name }}
  podMetricsEndpoints:
    - port: http
      path: /metrics
      interval: 15s

1.6 templates/scaledobject.yaml

apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ .Values.nameOverride | default .Release.Name }}
  labels:
    app: {{ .Values.nameOverride | default .Release.Name }}
spec:
  scaleTargetRef:
    name: {{ .Values.nameOverride | default .Release.Name }}
  minReplicaCount: {{ .Values.replicas.min }}
  maxReplicaCount: {{ .Values.replicas.max }}
  cooldownPeriod: {{ .Values.cooldown }}
  triggers:
    # 1) RPS vía Prometheus
    - type: prometheus
      metadata:
        serverAddress: http://{{ .Values.promStackRelease }}-kube-prometheus-prometheus.monitoring.svc:9090
        metricName: http_requests_per_second
        threshold: "{{ .Values.thresholds.rps }}"
        query: |
          sum(rate(http_requests_total{pod=~"{{ .Values.nameOverride | default .Release.Name }}.*"}[1m]))
    # 2) % CPU
    - type: cpu
      metadata:
        # 'type' puede ser 'Utilization' o 'AverageValue'.
        # Usamos Utilization (porcentaje) para que coincida con 'thresholds.cpu'.
        type: Utilization
        value: "{{ .Values.thresholds.cpu }}"

2 . Aplicación FastAPI app/

(sin cambios respecto a la versión anterior)

3 . Script scripts/setup.sh (actualizado)

#!/usr/bin/env bash
set -euo pipefail

if ! command -v helm &>/dev/null; then
  curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if ! minikube status -p keda-demo &>/dev/null; then
  minikube start -p keda-demo --memory 4096 --cpus 4 --driver=docker
fi

helm repo add kedacore https://kedacore.github.io/charts || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

kubectl create namespace keda --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install keda kedacore/keda -n keda

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install kube-prom prometheus-community/kube-prometheus-stack -n monitoring \
  --set grafana.enabled=false \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false

echo "🎉 Entorno listo. Construye la imagen y despliega la API."

4 . Pasos de uso

4.1 Provisionar clúster + KEDA + Prometheus

./scripts/setup.sh

4.2 Construir imagen local y desplegar la API

eval $(minikube -p keda-demo docker-env)

docker build -t demo-api:latest ./app

eval $(minikube -p keda-demo docker-env -u)

helm upgrade --install demo-api ./charts/demo-api \
  --set image.repository=demo-api \
  --set image.tag=latest \
  --set image.pullPolicy=IfNotPresent

4.3 UI de Prometheus

kubectl -n monitoring port-forward svc/kube-prom-kube-prometheus-prometheus 9090 &
# Navegador ⇒ http://localhost:9090
# Consulta: sum(rate(http_requests_total{pod=~"demo-api.*"}[1m]))

4.4 Generar carga y ver el escalado

watch -n2 kubectl get hpa,pods

kubectl run --rm -it loadgen --image=busybox -- \
  sh -c "while true; do wget -q -O- http://{{ .Values.nameOverride | default .Release.Name }}:8000/; done"

4.5 Limpiar

minikube delete -p keda-demo