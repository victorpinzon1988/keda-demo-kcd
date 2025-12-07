# KEDA Demo – KCD

Repositorio de demostración para KCD FDay Guatemala 2025 para explicar **autoescalamiento con KEDA sobre Kubernetes**.

La demo crea un entorno completo con Minikube, instala HELM para el manejo de dependencias, instala KEDA, despliega una API y genera carga para observar cómo escalan los pods automáticamente.
El objetivo es que escale en base a una métrica de requests por segundos.

---

##  1. Arquitectura de la Demo

La arquitectura incluye:

- **Kubernetes local Minikube**
- **Aplicación demo**  
  - Código en `app/`  
  - Imagen Docker construida desde este repo
- **Chart de Helm** para la API (`charts/demo-api/`)
- **KEDA** como operador de autoscaling
- **Stack de monitoreo**  
  - Prometheus
- **Scripts de automatización** (`scripts/`):
  - Instalación del clúster y KEDA
  - Despliegue de la demo
  - Generación de carga
  - Limpieza

---

##  2. Requisitos

| Herramienta | Versión mínima recomendada |
|------------|-----------------------------|
| Docker     | 24.x                        |
| kubectl    | 1.29                        |
| Minikube   | 1.33                        |
| Helm 3     | 3.14                        |


---

## 3. Puesta en Marcha Rápida

### 3.1 Clonar el repositorio

```bash
git clone https://github.com/victorpinzon1988/keda-demo-kcd.git
cd keda-demo-kcd
```

### 3.2 Provisionar Minikube + Keda + Prometheus

```bash
./scripts/setup.sh
```

## 4. Desplegar la API Demo

### 4.1 Instalacion del chart
```bash
kubectl create namespace keda-demo || true

helm upgrade --install demo-api charts/demo-api \
  -n keda-demo
```

### 4.2 Validacion:
```bash
kubectl get pods -n keda-demo
kubectl get svc  -n keda-demo
```

### 4.3 Obtener URL del API:
```bash
minikube service -n keda-demo demo-api --url
```

## 5. Probar autoescalamiento con KEDA

### 5.1 Revision del ScaledObject
```bash
kubectl get scaledobjects -A
kubectl describe scaledobject <nombre> -n keda-demo
```

### 5.2 Generacion de la carga utilizando curl
```bash
URL=$(minikube service -n keda-demo demo-api --url)

while true; do curl -s "$URL/"; done
```

### 5.3 Monitoreo de los pods
```bash
watch -n 2 "kubectl get hpa,pods -n keda-demo"

```


