# Arquitectura y Estructura del Sistema (Práctica 5)

Este documento detalla la arquitectura completa de la plataforma de microservicios, el propósito de cada archivo clave en el repositorio y cómo todos los componentes interactúan entre sí dentro del clúster de Kubernetes.

---

## 1. Visión General de la Arquitectura

El sistema es una plataforma de **Microservicios** orquestada mediante **Kubernetes** y empaquetada usando **Helm**. Sigue los principios de alta disponibilidad, autoescalado y separación de responsabilidades.

### Diagrama de Flujo y Topología

```mermaid
graph TD
    %% Nodos
    Client(("Usuario / Postman"))

    subgraph Kubernetes Cluster [Clúster Kubernetes - Namespace: sa-p5]
        Ingress["Ingress Controller<br/>(Minikube Tunnel)"]
        Gateway["API Gateway<br/>(NGINX Proxy)"]
        
        subgraph Microservicios [Lógica de Negocio]
            Auth["Auth Service"]
            Transaction["Transaction Service"]
            Approval["Approval Service"]
            Notification["Notification Service"]
        end
        
        subgraph Almacenamiento [Estado y Colas]
            Postgres[("PostgreSQL<br/>(StatefulSet)")]
            RabbitMQ{"RabbitMQ<br/>(StatefulSet)"}
        end
        
        subgraph Tareas Programadas [CronJobs]
            CronInsert(("CronJob<br/>Insert DB"))
            CronSummary(("CronJob<br/>Summary Broker"))
        end
    end

    %% Conexiones de Entrada
    Client -->|"HTTP/REST"| Ingress
    Ingress -->|"Enruta tráfico"| Gateway
    
    %% Conexiones Síncronas (Gateway a MS)
    Gateway -->|"/api/auth"| Auth
    Gateway -->|"/api/transactions"| Transaction
    Gateway -->|"/api/approvals"| Approval
    Gateway -->|"/api/notifications"| Notification
    
    %% Conexiones a Base de Datos
    Auth -.->|"Consulta Rol"| Postgres
    Transaction -.->|"Guarda Transacción"| Postgres
    Approval -.->|"Aprueba Lote"| Postgres
    
    %% Conexiones Asíncronas (Broker)
    Transaction ==>|"Evento: Creado"| RabbitMQ
    Approval ==>|"Evento: Aprobado"| RabbitMQ
    RabbitMQ ==>|"Consume Eventos"| Notification
    
    %% Conexiones CronJobs
    CronInsert -.->|"Inserta masivo"| Postgres
    CronSummary ==>|"Publica resumen"| RabbitMQ
```

La arquitectura se compone de las siguientes piezas principales:
*   **API Gateway (Nginx):** Punto de entrada único (Single Point of Entry) que enruta el tráfico externo hacia los microservicios internos adecuados.
*   **Microservicios (Node.js):** Lógica de negocio descentralizada (`auth`, `transaction`, `approval`, `notification`).
*   **Base de Datos (PostgreSQL):** Almacenamiento persistente centralizado para el estado de las transacciones.
*   **Message Broker (RabbitMQ):** Sistema de colas para comunicación asíncrona entre microservicios (patrón Productor/Consumidor).
*   **CronJobs:** Tareas programadas por Kubernetes para ejecutar lotes de trabajo sin intervención humana.

---

## 2. Flujo de Comunicación (¿Cómo se conecta todo?)

1.  **Ingreso de Tráfico:** El usuario o K6 envía una petición a `sa-platform.local`. El **Ingress Controller** de Kubernetes intercepta esto en el puerto 80.
2.  **Enrutamiento Inicial:** El Ingress redirige el tráfico al servicio interno del **API Gateway**.
3.  **Proxy Inverso:** El API Gateway (Nginx) lee la ruta (ej. `/api/auth/`) y usa DNS interno de Kubernetes para redirigir la petición al microservicio correspondiente (`auth-service`).
4.  **Autorización (Auth Service):** Los servicios verifican los roles enviando peticiones internas de validación antes de ejecutar operaciones críticas.
5.  **Procesamiento Asíncrono:** Cuando el `transaction-service` crea una transacción, la guarda en **PostgreSQL**, pero también lanza un evento en **RabbitMQ**.
6.  **Reacción:** El `notification-service` y `approval-service`, que están "escuchando" a RabbitMQ, reciben el evento asíncrono y actúan (ej. enviando una notificación o aprobando) sin bloquear al usuario.
7.  **Autoescalado:** Si el tráfico sube abruptamente, el **Horizontal Pod Autoscaler (HPA)** detecta el consumo de CPU a través del Metrics Server y levanta nuevas réplicas (pods) de los microservicios afectados.

---

## 3. Diccionario de Archivos y Directorios Clave

A continuación, se detalla la responsabilidad exacta de cada carpeta y archivo del proyecto:

### 📂 `src/` (Código Fuente de la Aplicación)
Contiene el código fuente que se "dockeriza" para ejecutar los contenedores.
*   **`api-gateway/`**: 
    *   `nginx.conf`: Configura el servidor Nginx para actuar como proxy inverso. Contiene los `upstream` que mapean rutas externas (ej. `/api/transactions`) a los nombres DNS internos de los microservicios de Kubernetes.
*   **`auth-service/`, `approval-service/`, `transaction-service/`, `notification-service/`**:
    *   `server.js` / `index.js`: Lógica de negocio en Express/Node.js. Aquí se manejan peticiones, validaciones de permisos, conexiones a la BD y al Broker.
    *   `Dockerfile`: Las instrucciones para empaquetar el código de Node.js en una imagen ligera que Kubernetes pueda ejecutar.
*   **`cronjobs/`**: Scripts independientes que se empaquetan en Docker para ser ejecutados esporádicamente por Kubernetes (inserción de datos masiva y resumen de broker).

### 📂 `charts/sa-platform/` (Orquestación e Infraestructura)
Contiene toda la definición de infraestructura como código (IaC) en formato Helm.
*   **`Chart.yaml`**: Archivo maestro del chart. Define la versión del paquete y, críticamente, las **dependencias** (aquí se declaran PostgreSQL y RabbitMQ para que Helm los descargue de repositorios oficiales).
*   **`values.yaml`** / **`values-dev.yaml`**: Configuración base y de desarrollo. Define variables de entorno, desactiva el HPA (replicas fijas en 1) y define qué imágenes Docker usar.
*   **`values-prod.yaml`**: Sobrescribe a `values.yaml` para el ambiente de Producción. Aumenta las `replicaCount` iniciales y configura recursos, lo que detona el inicio de los Autoescaladores (HPA).
*   **`templates/`**:
    *   `ingress.yaml`: Define la regla de entrada a Kubernetes (mapea el host `sa-platform.local` hacia el API Gateway).
    *   `network-policies.yaml`: Define las reglas de firewall interno de Kubernetes (ej. prohíbe que el `auth-service` se comunique directamente con la base de datos).
    *   `rabbitmq.yaml`: Plantilla especial que sobrescribe el StatefulSet por defecto del Broker para solucionar problemas de metadatos obsoletos, usando la imagen pura `rabbitmq:3.13-management`.
    *   `cronjobs.yaml`: Configura las tareas programadas de Kubernetes, indicando qué imagen ejecutar y bajo qué esquema de tiempo (ej. `*/5 * * * *`).

### 📂 `charts/sa-platform/charts/microservice/` (El "Sub-Chart")
Para no copiar y pegar el mismo código 4 veces (para los 4 microservicios), se diseñó un "Sub-chart" genérico. Todo microservicio que use este sub-chart hereda automáticamente:
*   **`deployment.yaml`**: Instrucciones para que Kubernetes despliegue los pods del microservicio. Contiene lógica para montar sidecars, liveness probes y read-only filesystems.
*   **`service.yaml`**: Crea el balanceador de carga interno de capa 4. Da una IP estable y un nombre de DNS interno (ej. `http://sa-platform-auth-service`) a un grupo de pods.
*   **`hpa.yaml`**: El Horizontal Pod Autoscaler. Monitorea la métrica de CPU (TARGETS) y aumenta dinámicamente la cantidad de pods entre `minReplicas` y `maxReplicas`.

### 📂 Raíz del Proyecto
*   **`GUIA_DESPLIEGUE.md`**: El manual de operaciones (Runbook). Describe los pasos para levantar el entorno desde cero, compilar dependencias, y simular pruebas de carga y rollbacks.
*   **`secrets-values.yaml`**: Archivo crítico de seguridad. Contiene contraseñas en texto plano para inyectar en las bases de datos y brokers. **Nunca** debe subirse a Git (usualmente se ignora en `.gitignore`), protegiendo el entorno contra filtraciones de credenciales.
*   **`scripts/load-test.js`**: Script de pruebas de K6. Simula usuarios concurrentes atacando la plataforma. Sirve para inyectar picos de estrés (CPU) y auditar el comportamiento del HPA de Kubernetes en Producción.

---

## 4. Conclusión del Diseño
El diseño de la plataforma sigue **Mejores Prácticas Cloud Native**:
1.  **Inmutabilidad**: Las imágenes Docker no cambian entre Dev y Prod, solo cambian las configuraciones inyectadas vía Helm (`values.yaml`).
2.  **Seguridad Zero Trust**: El uso de Network Policies garantiza que, si un atacante vulnera un microservicio, no tendrá red hacia componentes a los que no debería tener acceso.
3.  **Resiliencia**: Si un pod colapsa, el Deployment (ReplicaSet) crea uno nuevo. Si el clúster se satura, el HPA crea más pods. RabbitMQ garantiza que no se pierdan mensajes si un servicio está temporalmente caído.
