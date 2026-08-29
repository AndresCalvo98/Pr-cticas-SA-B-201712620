# 📋 Guía de Calificación (Acordeón para la Rúbrica)

Este documento mapea **exactamente** los puntos de tu rúbrica de calificación con los componentes de tu proyecto. Úsalo como tu "Acordeón" o "Cheat-sheet" durante la presentación para asegurarte de que el auxiliar te califique con el 100%.

---

## 🟢 1. Habilidades (40 Puntos)

### 1.1 Documentación técnica y diagrama de arquitectura (12 pts)
* **Dónde está:** Abre el archivo `ARQUITECTURA.md`.
* **Qué mostrar/decir:** *"En este archivo documenté toda la visión general del flujo. Justo al principio agregué un diagrama dinámico en Mermaid que muestra exactamente cómo fluye la data desde Postman, pasando por el Ingress, hasta RabbitMQ y la Base de Datos. Además, el archivo `EXPLICACION_TECNICA.md` profundiza en cada concepto."*

### 1.2 Calidad y estructura del chart de Helm (12 pts)
* **Dónde está:** Abre la carpeta `charts/sa-platform/charts/microservice`.
* **Qué mostrar/decir:** *"No repetí código. Creé un Sub-chart genérico llamado `microservice` que contiene las plantillas maestras (`deployment.yaml`, `service.yaml`, `hpa.yaml`). Luego, en el `values.yaml` principal, simplemente defino 'alias' (ej. `auth-service`, `transaction-service`) para reutilizar esa misma plantilla pasándole variables distintas."*

### 1.3 Organización del repositorio (3 pts)
* **Dónde está:** Muestra la estructura de carpetas en tu editor (VSCode).
* **Qué mostrar/decir:** *"Todo está separado por responsabilidad: tengo la carpeta `charts` para la infraestructura como código (Helm), `scripts` para las pruebas de carga, y mis archivos de documentación markdown están sueltos en la raíz para fácil acceso."*

### 1.4 Lista de comandos reproducibles (3 pts)
* **Dónde está:** Abre el archivo `GUIA_DESPLIEGUE.md`.
* **Qué mostrar/decir:** *"Escribí un Runbook completo. Literalmente cualquier persona puede levantar el proyecto desde cero copiando y pegando secuencialmente los comandos de este archivo. Nada se hace manualmente."*

### 1.5 Preguntas teóricas (10 pts)
* **Dónde está:** Tu mente y el archivo `EXPLICACION_TECNICA.md`.
* **Qué mostrar/decir:** (Depende de lo que te pregunten, apóyate en ese documento si olvidas algún concepto como la diferencia entre Liveness y Readiness).

---

## 🔵 2. Conocimiento (60 Puntos)

### 2.1 Ciclo de vida con Helm (install, upgrade y rollback) (12 pts)
* **Dónde está:** Se demuestra en la terminal siguiendo el `GUION_PRESENTACION.md`.
* **Qué mostrar/decir:** 
  * `helm install`: Se demuestra al levantar el ambiente Dev.
  * `helm upgrade`: Se demuestra cuando aplicas `values-prod.yaml` para encender el Autoescalado.
  * `helm rollback`: Se demuestra cuando borras los deployments y corres el downgrade a `values-dev.yaml` simulando una emergencia.

### 2.2 Configuración, secretos y persistencia (10 pts)
* **Dónde está:** Archivos `secrets-values.yaml`, `values.yaml` y la terminal.
* **Qué mostrar/decir:** 
  * **Secretos:** *"Inyecté las contraseñas de RabbitMQ y Postgres a través de un archivo `secrets-values.yaml` externo, el cual en la vida real ignoramos en Git para que las credenciales nunca queden hardcodeadas en el código."*
  * **Persistencia:** Corre `kubectl get pvc -n sa-p5` y muéstrale que Postgres y RabbitMQ tienen un volumen de 1Gi atado (PersistentVolumeClaim). *"Si borro el pod de la base de datos, el nuevo pod se reconecta a este disco duro virtual y no pierdo la data."*

### 2.3 Comunicación asíncrona mediante broker (12 pts)
* **Dónde está:** Terminal (Postman) y `kubectl get pods`.
* **Qué mostrar/decir:** Abre Postman, envía una petición de crear transacción. Luego dile: *"La petición no espera a que el Notification Service termine. El Transaction Service simplemente avienta el mensaje a RabbitMQ (encargado de la asincronía) y responde rápido al cliente. RabbitMQ se asegura de que el Notification Service lo reciba a su propio ritmo."*

### 2.4 Exposición, aislamiento de red y seguridad (10 pts)
* **Dónde está:** Archivos `ingress.yaml` y `network-policies.yaml`.
* **Qué mostrar/decir:** 
  * **Exposición:** *"Usé Ingress y un API Gateway (Nginx) para tener un único punto de entrada (Puerto 80). Los demás microservicios no tienen IP pública (son ClusterIP)."*
  * **Aislamiento:** *"Definí Network Policies para aplicar seguridad Zero Trust. Por ejemplo, el servicio Auth está bloqueado a nivel de red para hablar con la Base de Datos; solo Transaction y Approval tienen permiso en el firewall interno de Kubernetes."*

### 2.5 Escalado y resiliencia bajo carga (10 pts)
* **Dónde está:** K6 y HPA (Pasos 3 y 4 del `GUION_PRESENTACION.md`).
* **Qué mostrar/decir:** *"Tengo un HPA configurado al 70% de CPU."* Lanza el ataque con `kubectl replace --force -f scripts/k6-pod.yaml -n sa-p5`, deja abierta la terminal con `kubectl get hpa -n sa-p5 -w` y muéstrale cómo los pods suben de 2 a 4 cuando la CPU sobrepasa el límite.

### 2.6 Cronjobs encadenados y funcionales (6 pts)
* **Dónde está:** Terminal (`kubectl get cronjobs -n sa-p5`).
* **Qué mostrar/decir:** Corre ese comando y muéstrale que tienes tareas programadas. *"Configuré dos CronJobs. El primero se levanta cada X tiempo e inserta registros directo a la BD. El segundo lee esos datos y avienta un resumen estadístico al broker RabbitMQ. Una vez que terminan su código, Kubernetes destruye el contenedor para no gastar RAM inútilmente (quedan en estado Completed)."*
