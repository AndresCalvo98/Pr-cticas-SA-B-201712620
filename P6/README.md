# Práctica 6: Despliegue de Plataforma en Kubernetes en la Nube (Azure AKS)

Este repositorio contiene la adaptación de la Práctica 5 para su despliegue en un entorno Cloud real, utilizando **Azure Kubernetes Service (AKS)** y **Azure Container Registry (ACR)**.

## 🌐 1. Exposición Pública (Evidencia)

El sistema ha sido expuesto exitosamente a internet mediante un **Nginx Ingress Controller** aprovisionado en Azure con una IP Pública.

*   **IP Pública de Acceso:** `135.234.193.198`

> [!IMPORTANT]  
> **Rutas de Prueba Válidas**  
> El API Gateway (Nginx) no cuenta con una ruta raíz (`/`) ni un `/graphql` global. Para probar el clúster correctamente, se deben utilizar las rutas específicas configuradas en el proyecto (también puedes importar la colección de Postman incluida en esta carpeta):
> *   REST Auth: `http://135.234.193.198/api/auth/authorize` (POST)
> *   REST Transactions: `http://135.234.193.198/api/transactions/upload` (POST)
> *   REST Approvals: `http://135.234.193.198/api/approvals/batch-123` (POST)
> *   GraphQL Transactions: `http://135.234.193.198/graphql/transactions` (POST)
> *   GraphQL Approvals: `http://135.234.193.198/graphql/approvals` (POST)

---

## 🛠️ Adaptaciones Clave para Azure (Frente a Minikube)
Además de subir las imágenes al Container Registry, fue necesario realizar las siguientes adaptaciones en los manifiestos:
1. **Health Probes del Load Balancer:** Se configuró el Ingress de Nginx para responder las pruebas de estado de Azure en la ruta `/healthz`, evitando que Azure marcara la IP como caída por falta de un backend por defecto (`404`).
2. **Corrección de Rewrite-Target:** Se eliminó la anotación `rewrite-target: /` del Ingress, la cual reescribía de forma destructiva las peticiones (ej. `/graphql/transactions` -> `/`), rompiendo el esquema de rutas de Nginx.
3. **Nombre del Backend del Ingress:** Se actualizó la referencia del Ingress para que apunte a `sa-platform-api-gateway`, respetando el prefijo dinámico que Helm le inyecta a los servicios.

---

## 🚀 2. Procedimiento Completo de Despliegue

### Paso 1: Creación de Infraestructura (Azure CLI)
Se aprovisionaron los recursos utilizando el CLI de Azure:
```bash
# 1. Grupo de Recursos
az group create --name rg-sa-p6 --location eastus

# 2. Azure Container Registry (Registro de Contenedores Privado)
az acr create --resource-group rg-sa-p6 --name acrsap6andres --sku Basic

# 3. Clúster de Kubernetes (AKS) con 2 Nodos
az aks create --resource-group rg-sa-p6 --name aks-sa-p6 --node-count 2 --node-vm-size Standard_D2as_v7 --generate-ssh-keys --attach-acr acrsap6andres --network-plugin azure

# 4. Obtener credenciales para kubectl
az aks get-credentials --resource-group rg-sa-p6 --name aks-sa-p6 --overwrite-existing
```

### Paso 2: Construcción y Publicación de Imágenes
Se utilizó el script `build-and-push.ps1` (incluido en este directorio) para compilar las imágenes localmente y subirlas al ACR:
```bash
az acr login --name acrsap6andres
docker build -t acrsap6andres.azurecr.io/api-gateway:latest ./src/api-gateway
docker push acrsap6andres.azurecr.io/api-gateway:latest
# (Este proceso se repitió para los 4 microservicios y los 2 cronjobs)
```

### Paso 3: Despliegue con Helm
Se instaló el Nginx Ingress Controller (que solicita automáticamente un Load Balancer a Azure) y luego se desplegó el Chart de la plataforma inyectando el archivo `values-aks.yaml` (que apunta al ACR) y los secretos:
```bash
# Instalar Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# Desplegar la Plataforma
helm install sa-platform ./charts/sa-platform -f ./charts/sa-platform/values-aks.yaml -f secrets-values.yaml --namespace sa-p6 --create-namespace
```

---

## 🗑️ 3. Procedimiento de Eliminación de Recursos

Para evitar cobros innecesarios una vez calificada la práctica, se debe ejecutar el siguiente comando. Al eliminar el "Resource Group", Azure destruye en cascada el Clúster AKS, el ACR, los discos (PVCs) y la IP Pública:

```bash
az group delete --name rg-sa-p6 --yes --no-wait
```

---

## 💰 4. Costo Aproximado del Despliegue

| Recurso | Descripción / SKU | Costo Mensual Estimado | Costo por Hora |
| :--- | :--- | :--- | :--- |
| **AKS Control Plane** | Nivel Free | $0.00 | $0.00 |
| **Nodos (VMs)** | 2 x `Standard_D2as_v7` | ~$140.00 | ~$0.19 |
| **Container Registry** | Basic SKU | ~$5.00 | ~$0.007 |
| **Load Balancer / IP** | Standard Public IP | ~$3.00 | ~$0.004 |
| **Discos (PVC)** | 1Gi Premium SSD (Postgres) | ~$0.15 | ~$0.0002 |
| **TOTAL ESTIMADO** | | **~$148.15 / mes** | **~$0.20 / hora** |

> Como el clúster solo estará encendido unas horas para la calificación, **el costo real consumido de los créditos de Azure será menor a $1.00 USD**.

---

## 🧠 5. Respuestas a Interrogantes Teóricas

### 1. ¿Qué es un clúster de Kubernetes administrado y qué diferencias tiene frente a uno local?
Un clúster administrado (como Azure AKS o Google GKE) es un entorno donde el proveedor de la nube se encarga de gestionar, actualizar y mantener el **Control Plane** (los nodos maestros, la base de datos `etcd`, el scheduler, etc.), liberando al usuario de esa carga operativa.
*   **Diferencia principal:** En un clúster local (como Minikube), el usuario debe emular los nodos en su propia RAM/CPU y no tiene acceso a integraciones nativas de hardware (como IPs públicas reales o discos SSD distribuidos). En la nube, los recursos son físicos, escalables y respaldados por la red global del proveedor.

### 2. ¿Qué es un Service de tipo LoadBalancer y cómo lo implementa el proveedor de nube?
Es un objeto de Kubernetes que expone un servicio hacia el internet exterior. 
*   **Implementación:** Cuando Kubernetes detecta que creaste un servicio `LoadBalancer`, utiliza un *Cloud Controller Manager* interno que habla mediante APIs con el proveedor de la nube (en este caso Azure) para solicitarle que compre y aprovisione un balanceador de carga de hardware real (Azure Load Balancer) y le asigne una IP Pública que enrute el tráfico hacia los nodos del clúster.

### 3. ¿Qué es un registro de contenedores y por qué es necesario para desplegar en la nube?
Es un servicio de almacenamiento (como Azure Container Registry o Docker Hub) diseñado específicamente para alojar imágenes de Docker.
*   **Por qué es necesario:** Un clúster en la nube está compuesto por servidores remotos que empiezan "limpios". A diferencia de Minikube (que comparte el disco de tu computadora), los nodos de AKS no tienen tus imágenes locales. Necesitan un registro en internet de donde puedan hacer `docker pull` para descargar el código antes de correr los pods.

### 4. ¿Qué componentes del clúster administra el proveedor y cuáles siguen siendo responsabilidad del estudiante?
*   **El Proveedor (Azure) administra:** El plano de control (Control Plane), el servidor de la API de Kubernetes, la alta disponibilidad del `etcd`, la integración con la red de Azure y la reparación automática de hardware de los nodos si un servidor físico falla.
*   **El Estudiante administra:** Los Nodos de trabajo (Worker Nodes) en términos de elegir su tamaño y pagar por ellos, la configuración de los microservicios, la seguridad interna (Network Policies, RBAC, Secretos) y las actualizaciones de las aplicaciones instaladas.

### 5. ¿Qué costos genera el despliegue realizado y cómo podrían reducirse?
El despliegue genera un costo de aproximadamente **~$0.20 por hora** (detallado en la sección 4), proveniente del uso de máquinas virtuales de la serie D, la IP pública y el registro básico.
**Formas de reducirlo:**
1.  **Spot Instances:** Usar nodos "Spot" (máquinas de subasta con descuento de hasta 80%) para cargas que toleran interrupciones.
2.  **Escalabilidad a Cero:** Usar herramientas como KEDA para apagar los pods (0 réplicas) por las noches y usar un escalador automático de clúster (Cluster Autoscaler) que apague los nodos físicos cuando no se usen.
3.  **Tamaño de VM:** Elegir instancias de la serie B (Burstable), que son mucho más económicas, si la suscripción y la región lo permiten.
