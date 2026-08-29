# Práctica 5 - Orquestación Avanzada en Kubernetes con Helm

Este repositorio contiene la entrega final de la **Práctica 5**, donde se migra la plataforma bancaria de microservicios hacia un clúster de Kubernetes, empaquetado en un Chart de Helm (`sa-platform`) aplicando las mejores prácticas y principios *Clean Code* vistos en clase.

## 🛠️ Tecnologías y Prácticas Implementadas
- **Docker Multi-Stage**: Optimización extrema de las imágenes (ej. Node.js en Alpine) logrando ejecutarlas como usuarios sin privilegios (non-root) para cumplir con el principio de mínimo privilegio.
- **Async Messaging (RabbitMQ)**: Se eliminó el acoplamiento duro. Ahora el `approval-service` envía mensajes asíncronos y el `notification-service` actúa como consumidor *durable*. Si el worker se cae, no hay pérdida de mensajes.
- **Helm**: Empaquetamiento maestro. Dependencias administradas (Bitnami para RabbitMQ y PostgreSQL). Se usaron "alias" en el `Chart.yaml` y un subchart genérico (`microservice`) para respetar el principio **DRY (Don't Repeat Yourself)** y evitar código YAML duplicado.
- **Resiliencia & Autoescalado**: Cada servicio cuenta con *Liveness, Readiness y Startup Probes*. Se configuraron los *HPA* y un *PodDisruptionBudget* (`maxUnavailable: 0`) para garantizar 0% de downtime en *RollingUpdates*.
- **Seguridad y Aislamiento**: Un Ingress actúa como único punto de acceso. Las *NetworkPolicies* aseguran que los servicios no puedan hablar libremente entre sí o a la base de datos sin autorización explícita.
- **CronJobs**:
  - `cronjob1`: Inserta el carné en PostgreSQL (StatefulSet) cada 2 minutos.
  - `cronjob2`: Lee PostgreSQL y publica resumen en RabbitMQ cada 10 minutos.

---

## 🚀 Despliegue Reproducible (Comandos)

Esta lista describe los comandos exactos desde un clúster vacío (minikube/k3s) hasta el sistema operativo.

### 1. Preparar Clúster
Habilita addons necesarios en Minikube (si aplica):
```bash
minikube addons enable metrics-server
minikube addons enable ingress
```

### 2. Actualizar Dependencias de Helm
El chart requiere RabbitMQ y PostgreSQL. Se deben descargar antes de instalar:
```bash
cd charts/sa-platform
helm dependency update
```

### 3. Crear Namespace y Desplegar (Install)
Instalaremos el entorno completo en el namespace `sa-p5` usando el ambiente de desarrollo. No hace falta crear el namespace previamente si usamos `--create-namespace`:
```bash
helm install sa-platform . -f values-dev.yaml --namespace sa-p5 --create-namespace
```

### 4. Upgrade y Autoescalado (Simulación de Prod)
Para probar que el chart soporta parametrización (ej. más recursos y réplicas), podemos actualizar en vivo:
```bash
helm upgrade sa-platform . -f values-prod.yaml --namespace sa-p5
```

### 5. Verificar Tolerancia a Fallos (Rollback)
Si cometemos un error, el rollback es inmediato:
```bash
helm history sa-platform --namespace sa-p5
helm rollback sa-platform 1 --namespace sa-p5
```

---

## 🧪 Pruebas de Carga
Se incluye un script escrito en **k6** para golpear agresivamente el Ingress Controller y activar el `HorizontalPodAutoscaler` (HPA).
```bash
k6 run scripts/load-test.js
```
*Puedes monitorear el autoescalado en otra terminal con:*
```bash
kubectl get hpa -n sa-p5 -w
kubectl get pods -n sa-p5 -w
```
