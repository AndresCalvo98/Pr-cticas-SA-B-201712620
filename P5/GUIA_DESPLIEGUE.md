# Guía Definitiva de Despliegue y Calificación (A Prueba de Fallos)

Esta guía está diseñada específicamente para tu calificación de mañana. Contiene exactamente **qué comando ejecutar**, **dónde ejecutarlo**, y **qué debes explicarle al auxiliar** en cada paso para demostrar que dominas la arquitectura.

---

### Preparación (Antes de compartir pantalla)
1.  Asegúrate de tener **Docker Desktop** abierto y corriendo.
2.  Abre una terminal nueva de **PowerShell** y asegúrate de estar en la carpeta raíz `P5`.
3.  Levanta Minikube (recomendado darle buena memoria):
    ```powershell
    minikube start --memory=4096 --cpus=4
    ```

---

## PASO 1: Habilitar complementos vitales
**¿Qué decirle al auxiliar?** *"Primero vamos a habilitar el Ingress para exponer nuestra API Gateway, y el Metrics Server que es obligatorio para que el Autoescalador (HPA) pueda leer el consumo de CPU."*

```powershell
minikube addons enable metrics-server
minikube addons enable ingress
```

---

## PASO 2: Construir imágenes en el cerebro de Minikube
**¿Qué decirle al auxiliar?** *"Como las imágenes son locales, apuntaré mi consola al Docker interno de Minikube para que al compilar, queden directamente disponibles para el clúster sin necesidad de subirlas a Docker Hub."*

```powershell
# 1. Apuntar al entorno de Minikube
& minikube -p minikube docker-env | Invoke-Expression

# 2. Entrar a la carpeta de código fuente
cd src

# 3. Compilar todas las imágenes (Copia y pega todo el bloque)
docker build -t mi-repo/api-gateway ./api-gateway
docker build -t mi-repo/auth-service ./auth-service
docker build -t mi-repo/approval-service ./approval-service
docker build -t mi-repo/transaction-service ./transaction-service
docker build -t mi-repo/notification-service ./notification-service
docker build -t mi-repo/cronjob1 ./cronjobs/cronjob1
docker build -t mi-repo/cronjob2 ./cronjobs/cronjob2
```

---

## PASO 3: Dependencias Externas (Helm)
**¿Qué decirle al auxiliar?** *"Para la base de datos (PostgreSQL) y el Broker (RabbitMQ), configuré dependencias en Helm para no reinventar la rueda y descargar charts oficiales."*

```powershell
# Subir al directorio del chart principal
cd ../charts/sa-platform

# Descargar/Actualizar dependencias
helm dependency update
```

---

## PASO 4: Despliegue de Desarrollo (Install)
**¿Qué decirle al auxiliar?** *"Ahora desplegaré toda la plataforma en ambiente de Desarrollo. Voy a inyectar un archivo local `secrets-values.yaml` para mantener seguras las contraseñas sin subirlas al repositorio."*

```powershell
# Regresa a la raíz de P5
cd ../../

# Ejecuta el despliegue
helm install sa-platform ./charts/sa-platform -f ./charts/sa-platform/values-dev.yaml -f secrets-values.yaml --namespace sa-p5 --create-namespace
```

**Verifica que levanten:**
```powershell
kubectl get pods -n sa-p5 -w
```
*(Presiona `Ctrl+C` cuando veas que todo dice `1/1 Running`. Es normal que RabbitMQ y Postgres tarden un minuto).*

---

## PASO 5: Prueba de Fuego (Validar la API)
**¿Qué decirle al auxiliar?** *"Para evitar conflictos de puertos en Windows con el Ingress, abriré un túnel directo al API Gateway usando Port-Forward para demostrar que la plataforma responde."*

1. **Abre una SEGUNDA terminal de PowerShell**, ve a la carpeta P5 y ejecuta:
   ```powershell
   kubectl port-forward svc/sa-platform-api-gateway 8080:80 -n sa-p5
   ```
   *(Déjala corriendo, no la cierres).*

2. **En tu PRIMERA terminal**, prueba el endpoint de autorización:
   ```powershell
   Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/auth/authorize" -Method Post -Headers @{"Content-Type"="application/json"} -Body '{"role":"Admin", "path":"/api/ruta1"}'
   ```
   **¿Qué esperar?** Debería imprimirte en pantalla `allowed: True`.

---

## PASO 6: Demostrar Upgrade a Producción
**¿Qué decirle al auxiliar?** *"Voy a simular un paso a Producción. Ejecutaré un Upgrade inyectando `values-prod.yaml`. Esto aumentará las réplicas base de mis servicios y, lo más importante, activará el Autoescalador (HPA)."*

```powershell
# En tu PRIMERA terminal (cierra el port-forward de la otra si quieres)
helm upgrade sa-platform ./charts/sa-platform -f ./charts/sa-platform/values-prod.yaml -f secrets-values.yaml --namespace sa-p5
```

Verás que automáticamente se crean nuevos pods para llegar a las 2 réplicas mínimas que exige Producción.

---

## PASO 7: Pruebas de Estrés (Autoescalado HPA con K6)
**¿Qué decirle al auxiliar?** *"Para probar el autoescalado, crearé un Pod efímero dentro del clúster inyectándole mi script de K6. Así atacaremos el API Gateway directamente desde adentro para generar carga de CPU."*

**1. Inyecta el script de pruebas en Kubernetes:**
```powershell
kubectl create configmap k6-script --from-file=load-test.js=scripts/load-test.js -n sa-p5
```

**2. Ejecuta el ataque (Copia todo este bloque y pégalo):**
```powershell
kubectl run k6-test --image=grafana/k6 --restart=Never -n sa-p5 --overrides='
{
  "apiVersion": "v1",
  "spec": {
    "containers": [
      {
        "name": "k6",
        "image": "grafana/k6",
        "command": ["k6", "run", "/scripts/load-test.js"],
        "volumeMounts": [
          {
            "name": "script-volume",
            "mountPath": "/scripts"
          }
        ]
      }
    ],
    "volumes": [
      {
        "name": "script-volume",
        "configMap": {
          "name": "k6-script"
        }
      }
    ]
  }
}
'
```

**3. Observa cómo escala el sistema:**
```powershell
kubectl get hpa -n sa-p5 -w
```
**¿Qué esperar?** En los próximos 1-2 minutos, verás cómo la columna de `TARGETS` sube (ej. `85%/70%`), y la columna `REPLICAS` pasa de 2 a 3, 4 o 5 pods automáticamente.

---

## PASO 8: Rollback de Emergencia
**¿Qué decirle al auxiliar?** *"Si la versión de producción tuviera un fallo crítico, Kubernetes con Helm nos permite volver a la versión exacta de desarrollo al instante."*

```powershell
# Regresar a la revisión número 1 (Desarrollo)
helm rollback sa-platform 1 -n sa-p5
```

---

## PASO 9: Destrucción Total (Limpieza)
Al finalizar la calificación, borras absolutamente todo limpiamente:

```powershell
helm uninstall sa-platform -n sa-p5
kubectl delete namespace sa-p5
```
