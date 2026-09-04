# Guion de Presentación (Entorno ya corriendo)

Si decides **no borrar nada esta noche** y presentarte con el clúster ya encendido y configurado en ambiente de Desarrollo, este es el orden exacto en el que debes mostrar las cosas para llevarte todos los puntos.

---

### Preparación Inmediata (Corre esto antes de compartir pantalla)
Para asegurar que todos los comandos de esta guía funcionen a la primera, abre tu terminal y entra a la carpeta P5:
```powershell
cd "Desktop\SA Practicas\Pr-cticas-SA-B-201712620\P5"
```
*(Mantén esta terminal abierta, todos los comandos siguientes se corren desde aquí).*

---

### 1. Demostración de Arquitectura y Código (5 Minutos)
Antes de mostrar consolas, explícale cómo estructuraste el proyecto:
* **El Chart Genérico (`charts/microservice`):** Enséñale que no copiaste y pegaste código para cada API. Creaste una plantilla genérica que se reutiliza para los 5 servicios usando dependencias (alias) en Helm. Eso es una excelente práctica.
* **Separación de Entornos:** Muéstrale que tienes dos archivos clave: `values-dev.yaml` y `values-prod.yaml`. Explícale que Desarrollo tiene 1 sola réplica sin HPA, y Producción tiene 2 réplicas mínimas con HPA activado.
* **Seguridad:** Menciona que usaste un archivo externo (`secrets-values.yaml`) para inyectar contraseñas, en lugar de tenerlas hardcodeadas en los repositorios.

### 2. Prueba de API con Postman (3 Minutos)
Demuestra que los microservicios se están comunicando correctamente detrás del API Gateway.

1. Asegúrate de tener el puerto abierto (abre otra terminal si no lo tienes):
   ```powershell
   kubectl port-forward svc/sa-platform-api-gateway 8080:80 -n sa-p5
   ```
2. Abre la colección de **Postman** que te generé (`SA_Practica5_Postman_Collection.json`).
3. Lanza la petición a `/api/auth/authorize`.
4. **¿Qué explicarle?** *"Como pueden ver, hice la petición a mi Nginx (API Gateway) en el puerto 8080, y el Gateway supo enrutarla internamente al Auth-Service por ClusterIP, devolviendo `allowed: true`."*

### 3. Upgrade a Producción (Alta Disponibilidad) (3 Minutos)
Llegó el momento de mover el clúster a producción en vivo.

1. Ejecuta el Upgrade:
   ```powershell
   helm upgrade sa-platform ./charts/sa-platform -f ./charts/sa-platform/values-prod.yaml -f secrets-values.yaml --namespace sa-p5
   ```
2. Muestra los pods:
   ```powershell
   kubectl get pods -n sa-p5
   ```
3. **¿Qué explicarle?** *"Acabo de inyectar el archivo de Producción. Kubernetes, sin tirar el servicio actual, acaba de levantar una segunda réplica de cada microservicio para garantizar Alta Disponibilidad (HA). Además, esto acaba de encender el Autoescalador (HPA)."*

### 4. Prueba de Estrés y Autoescalado (HPA) (4 Minutos)
El plato fuerte de la práctica. Vamos a saturar el sistema.

1. Lanza el ataque con K6 (el ConfigMap ya debe estar creado si no borraste nada):
   ```powershell
   kubectl replace --force -f scripts/k6-pod.yaml -n sa-p5
   ```
2. Abre el monitor del Autoescalador:
   ```powershell
   kubectl get hpa -n sa-p5 -w
   ```
3. **¿Qué explicarle?** *"Lancé un Pod temporal dentro de Kubernetes con un script de K6 para bombardear el API Gateway. El HPA está configurado para escalar si la CPU pasa del 70%. Como ven, la CPU llegó al X%, y Kubernetes automáticamente subió las réplicas de 2 a 3/4 pods para soportar la carga."*

### 5. Demostración de Tareas en Segundo Plano (CronJobs) (2 Minutos)
Esta parte demuestra que tienes trabajos independientes ejecutándose en el clúster.

1. Muestra la lista de CronJobs configurados:
   ```powershell
   kubectl get cronjobs -n sa-p5
   ```
2. Muestra que los CronJobs han dejado pods en estado "Completed":
   ```powershell
   kubectl get pods -n sa-p5
   ```
3. Conéctate a la Base de Datos para demostrar que el CronJob "insert-db" realmente guardó los datos:
   ```powershell
   kubectl exec -i sa-platform-postgresql-0 -n sa-p5 -- env PGPASSWORD=123456 psql -U AndresCalvo -d transacciones -c "SELECT * FROM cron_logs ORDER BY executed_at DESC LIMIT 5;"
   ```
4. **¿Qué explicarle?** *"Como pueden ver, no solo respondemos a peticiones HTTP. Tenemos CronJobs nativos de Kubernetes que cada 2 minutos (por ejemplo) despiertan, ejecutan un script, insertan un registro con mi carné en la Base de Datos o publican en RabbitMQ, y luego se destruyen solos (estado Completed) para no gastar memoria."*

### 6. Rollback / Regreso a Desarrollo (2 Minutos)
Simularemos que queremos regresar el ambiente a 1 sola réplica sin interrumpir Kubernetes.

1. Elimina los deployments para liberar el "Candado" que puso el Autoescalador:
   ```powershell
   kubectl delete deployment --all -n sa-p5
   ```
2. Regresa a la versión de Desarrollo usando Helm:
   ```powershell
   helm upgrade sa-platform ./charts/sa-platform -f ./charts/sa-platform/values-dev.yaml -f secrets-values.yaml --namespace sa-p5
   ```
3. **¿Qué explicarle?** *"Si algo sale mal en Producción o termina nuestro horario pico, gracias a Helm podemos inyectar de vuelta el archivo de desarrollo y Kubernetes apaga la Alta Disponibilidad, regresando el clúster a 1 sola réplica limpia. El sistema es totalmente resiliente."*

---
**Nota:** Al terminar tu calificación, ahora sí puedes correr el **Paso 9** de la `GUIA_DESPLIEGUE.md` (`helm uninstall...`) para apagar todo y liberar la RAM de tu computadora.
