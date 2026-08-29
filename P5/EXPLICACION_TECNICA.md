# Explicación Técnica y Arquitectónica - Práctica 5

Este documento es tu "acordeón" o guía de estudio para entender a la perfección qué hicimos, por qué lo hicimos, dónde está cada cosa y cómo funciona bajo el capó. Está redactado para que puedas defender el proyecto con total seguridad ante cualquier pregunta del auxiliar.

---

## 1. ¿Qué teníamos que hacer?
Migrar los 4 microservicios de la Práctica 4 a **Kubernetes**, empaquetarlos usando **Helm**, agregarles base de datos persistente (**PostgreSQL**), comunicación asíncrona (**RabbitMQ**) y asegurar el clúster con políticas de recursos, seguridad (RBAC/NetworkPolicies) y alta disponibilidad (HPA/Probes). Todo esto de la forma más profesional posible y aplicando **Clean Code**.

---

## 2. Mapa del Proyecto (Dónde está cada cosa)

Toda nuestra solución vive en la carpeta `P5`. Esta es la anatomía del proyecto:

### 📂 `P5/src/` (El Código Fuente)
Aquí viven nuestros microservicios.
*   **`approval-service/`** y **`notification-service/`**: Fueron los elegidos para cumplir el requisito de "Comunicación Asíncrona". El *approval* fue modificado para publicar un mensaje en RabbitMQ (`notifications_queue`) cuando autoriza un lote. El *notification* fue modificado para ser un consumidor continuo (Worker) de esa misma cola.
*   **`cronjobs/`**: Contiene el código en Node.js de nuestras tareas programadas. 
    *   `cronjob1`: Se conecta a Postgres e inserta tu carné y fecha cada 2 mins.
    *   `cronjob2`: Lee de Postgres, cuenta las ejecuciones y manda el resumen a RabbitMQ cada 10 mins.
*   **`Dockerfile` (en cada carpeta)**: Todos aplican **Multi-Stage Builds**. Compilamos/Instalamos dependencias en una etapa (Alpine) y copiamos solo lo necesario a una etapa limpia, declarando un usuario `non-root` para que no corran como administradores (requisito de seguridad).

### 📂 `P5/charts/sa-platform/` (El Motor de Despliegue - Helm)
Aquí ocurre la magia de la orquestación.
*   **`Chart.yaml`**: Define las dependencias externas (RabbitMQ y PostgreSQL de Bitnami) y declara nuestros microservicios usando **Alias**.
*   **`charts/microservice/`**: **Nuestra obra maestra de Clean Code (DRY)**. En vez de copiar archivos YAML 5 veces, hicimos una plantilla universal. Este chart sabe cómo levantar un Deployment, un Service, un HPA y aplicar Probes.
*   **`values.yaml`**, **`values-dev.yaml`**, **`values-prod.yaml`**: Son los "controles de mando". Aquí le decimos a Helm: *"Levanta 1 réplica del approval-service en Dev, pero levanta 2 en Prod y dale más CPU"*.
*   **`templates/`**:
    *   `ingress.yaml`: El único punto de entrada de la red hacia nuestro `api-gateway`.
    *   `network-policies.yaml`: Reglas estrictas de firewall. Los microservicios no pueden hablar entre sí a menos que estén explícitamente autorizados en este archivo.
    *   `secret.yaml` y `configmap.yaml`: Donde se manejan las variables de entorno sin dejar contraseñas quemadas.
    *   `cronjobs.yaml`: La definición para Kubernetes de que corra los scripts que hicimos en `/src/cronjobs/`.
    *   `resource-quota.yaml`: Pone un límite máximo de CPU y RAM que el namespace no puede sobrepasar.

---

## 3. ¿Cómo funciona la estrategia DRY (Don't Repeat Yourself) en Helm?

Si te preguntan: *"¿Por qué solo hay una carpeta 'microservice' si tenías que empaquetar 5 servicios?"*

**Tu respuesta:**
> "Aplicando Clean Code, me di cuenta que los 5 microservicios comparten la misma estructura base en Kubernetes (necesitan un Deployment, un ClusterIP Service, un Autoscaler, etc.). Duplicar archivos YAML es Deuda Técnica. 
> Por lo tanto, creé un subchart genérico (`charts/microservice`). Luego, en el archivo `Chart.yaml` principal, utilicé la propiedad de Helm llamada **`alias`** para importar ese mismo chart 5 veces bajo distintos nombres (`auth-service`, `transaction-service`, etc.). Finalmente, a través del `values.yaml`, le inyecto a cada alias la imagen Docker y el puerto que le corresponde. De esta forma, si necesito agregar un nuevo label estándar a toda la empresa, edito 1 solo archivo y los 5 servicios se actualizan mágicamente."

---

## 4. Respuestas a Conceptos Clave de la Práctica

*   **¿Qué es un StatefulSet y por qué tuvimos problemas al hacer el upgrade?**
    Se usa para bases de datos (PostgreSQL, RabbitMQ) porque mantiene la identidad de red y asocia un volumen persistente (PVC) fijo a cada pod. **Problema típico:** Los StatefulSets son inmutables en su `VolumeClaimTemplate`. Si intentas cambiar el tamaño del disco de 8Gi a 10Gi usando `helm upgrade`, Kubernetes lo rechaza para evitar pérdida de datos.
*   **Diferencia entre Liveness, Readiness y Startup Probes:**
    *   `Startup`: Verifica si la aplicación ya terminó de arrancar (útil si tarda mucho). Mientras no pase, las otras probes están pausadas. *Nota:* Tuvimos que deshabilitarlos temporalmente porque esperaban una respuesta HTTP 200 en la ruta raíz (`/`), pero nuestros microservicios solo respondían en `/api/...`, causando que Kubernetes matara los pods por "no arrancar".
    *   `Readiness`: Verifica si el pod está listo para recibir tráfico de usuarios. Si falla, el Ingress/Service lo saca del balanceo de carga.
    *   `Liveness`: Verifica si la app se quedó colgada (*deadlock*). Si falla, Kubernetes **mata el pod y crea uno nuevo**.
*   **¿Cómo lee el Autoescalador (HPA) el consumo de CPU?**
    El HPA no mide la CPU por sí solo. Depende de un componente central llamado **Metrics Server**. Este componente recolecta el consumo real de RAM y CPU de todos los nodos y pods, y el HPA consulta esta API para tomar la decisión matemática de escalar de 2 a 5 réplicas.
*   **¿Por qué ejecutamos K6 desde un Pod interno y no desde Windows?**
    Al tener Minikube corriendo dentro de WSL2/Docker, las redes puente hacen muy difícil que un contenedor externo (K6) resuelva las DNS internas de Kubernetes (como `sa-platform-api-gateway`). Para evitar configuraciones complejas de enrutamiento y hosts, inyectamos el script de JS en un **ConfigMap**, y creamos un Pod efímero con la imagen de K6 para que ataque al Gateway desde *adentro* del clúster con 100% de eficiencia.
*   **¿Qué problemas introduce la comunicación asíncrona?**
    Aunque mejora el rendimiento (evita cuellos de botella) e incrementa la resiliencia (los mensajes no se pierden si un servicio cae), introduce complejidad: los mensajes pueden duplicarse, llegar en desorden o ser difíciles de rastrear (traceability), requiriendo un Correlation ID en los logs.
*   **¿Qué hace helm rollback internamente?**
    Helm guarda el estado (manifiestos YAML) de cada `release` como un Secret dentro del propio clúster. Cuando haces rollback, Helm simplemente recupera los YAML de la revisión que le pediste y se los vuelve a aplicar a Kubernetes, forzando el estado anterior.
