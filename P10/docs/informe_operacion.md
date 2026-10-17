# 📊 Informe de Operación y Observabilidad (Plantilla Oficial 4.2)

**Universidad de San Carlos de Guatemala — Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas — Sistemas Avanzados (Segundo Semestre 2026)**  
**Estudiante:** Luis Andres Calvo Arreaga | **Carnet:** `201712620`  
**Práctica 10:** Observabilidad y Operación (del síntoma a la causa)  

---

## 1. 🎯 SLOs Declarados

### SLO 1: Disponibilidad de Transacciones en Producción
* **Indicador (SLI):** Ratio de respuestas HTTP exitosas (no-5xx) respecto al total recibido por los microservicios core.
  $$\text{SLI}_{\text{disp}} = \frac{\sum \text{rate}(\text{http\_requests\_total}\{\text{status}!\sim "5.."\} [5m])}{\sum \text{rate}(\text{http\_requests\_total}[5m])}$$
* **Objetivo:** $\ge 99.0\%$ de disponibilidad mensual.
* **Ventana de Medición:** Ventana móvil de 30 días (evaluada operativamente en intervalos multi-ventana de 5m, 1h y 6h).
* **Presupuesto de Error (Error Budget):** $1.0\%$ de peticiones con fallo tolerable (equivalente a 432 minutos de inactividad mensual permitida).
* **Justificación del Número:** La plataforma procesa pagos y cobros estudiantiles. Exigir 99.9% ("tres nueves") encarece desmedidamente la infraestructura redundante sin aportar valor perceptible al usuario que reintenta su pago, mientras que un 95% deterioraría inaceptablemente la confianza en la pasarela de transacciones. El 99.0% establece el equilibrio óptimo entre velocidad de entrega continua e inmunidad ante fallos esporádicos.

### SLO 2: Latencia de Peticiones Críticas
* **Indicador (SLI):** Percentil 95 ($p95$) de duración de solicitudes en el API Gateway y Transaction Service.
  $$\text{SLI}_{\text{lat}} = \text{histogram\_quantile}(0.95, \sum \text{rate}(\text{http\_request\_duration\_seconds\_bucket}[5m]) \text{ by } (le))$$
* **Objetivo:** $p95 \le 500\text{ ms}$.
* **Ventana de Medición:** Ventana móvil de 5 minutos evaluada continuamente.
* **Justificación del Número:** 500 ms representa el umbral psicológico en el que un usuario humano percibe fluidez e inmediatez en interfaces web y móviles. Respuestas por encima de 1000 ms provocan abandonos y clics repetidos que sobrecargan innecesariamente el backend.

---

## 2. 💥 Fallo Inducido

* **Componente Afectado:** `sa-platform-app-transaction-service` (Ruta `POST /api/transactions/process`).
* **Mecanismo de Inducción:** Se desplegó una versión candidata en Argo Rollouts configurada para inyectar deliberadamente una excepción `HTTP 500` con `ETIMEDOUT` hacia el almacenamiento de PostgreSQL en el 15% de las llamadas entrantes, simulando agotamiento repentino de conexiones en el pool.
* **Impacto Provocado:** La tasa de error del microservicio ascendió abruptamente de 0.0% a 14.8%, violando de inmediato el presupuesto de error y la cota de tolerancia del canary (< 1%).

---

## 3. ⏱️ Tiempo de Detección

* **Inicio del Fallo Inducido ($T_0$):** `2026-10-17T09:35:00Z`
* **Primera Señal en Tablero Grafana ($T_1$):** `2026-10-17T09:35:25Z` (25 segundos tras el inicio del tráfico anómalo; el panel de Tasa de Errores 5xx marcó 14.8%).
* **Disparo Formal de la Alerta en Alertmanager ($T_{\text{alerta}}$):** `2026-10-17T09:35:42Z`
* **Alerta Disparada:** `HighErrorBudgetBurnRate_1h` (Severidad: `CRITICAL`).
* **Tiempo Total de Detección:** **42 segundos** (0.7 minutos).
* **Respaldo de Marcas de Tiempo:** Evidenciado en el log de eventos de Alertmanager y en `P10/evidencias/recorrido_sintoma_causa.txt`.

---

## 4. 🧭 Recorrido hasta la Causa Raíz

El diagnóstico se ejecutó de forma lineal y correlacionada siguiendo los 3 pilares de observabilidad:

1. **De la Alerta al Tablero (32 segundos):**  
   Al recibir la notificación de `HighErrorBudgetBurnRate_1h`, el SRE abrió el `Tablero de Operación SRE` en Grafana. El panel de la 3ª Señal de Oro (Errores) focalizó el fallo exclusivamente en el `sa-transaction-service`.
2. **Del Tablero a la Traza en Tempo (33 segundos):**  
   Desde el panel de errores, se saltó a Grafana Tempo filtrando por spans con `status=error`. Se seleccionó la traza `4bf92f3577b34da6a3ce929d0e0e4736`. El span raíz (`sa-api-gateway`) evidenció 125 ms de duración con propagación del header `traceparent`, delegando en el span hijo de `sa-transaction-service`, el cual falló en la operación de base de datos con `db.error=connection timeout`.
3. **De la Traza al Log Estructurado en Loki (30 segundos):**  
   Haciendo clic en la correlación automática de Grafana (`Trace to Logs`) se ejecutó la consulta en Loki:  
   `{service="sa-transaction-service"} |= "4bf92f3577b34da6a3ce929d0e0e4736"`.  
   El log estructurado en JSON reveló la causa raíz exacta:
   ```json
   {
     "level": "ERROR",
     "service": "sa-transaction-service",
     "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
     "message": "Fallo en transacción: timeout en conexión al pool de PostgreSQL",
     "error_detail": "connect ETIMEDOUT 10.0.10.150:5432"
   }
   ```
* **Tiempo Total del Recorrido:** **1 minuto 48 segundos (108 s)**, cumpliendo la meta presencial (< 3 minutos).

---

## 5. 🛠️ Tiempo de Recuperación (RTO Operativo)

* **Hora de Restauración Estable ($T_{\text{recuperado}}$):** `2026-10-17T09:37:00Z`
* **Tiempo Total de Recuperación:** **2 minutos 00 segundos (120 s)**.
* **Resolutor:**
  1. *A nivel de despliegue:* Argo Rollouts detectó automáticamente el fallo en el `AnalysisRun` (`sa-platform-app-transaction-service-metrics-analysis-7c9f8d9b`) y abortó la promoción del canary en 25 segundos, desviando el 100% del tráfico a la versión estable anterior sin intervención manual.
  2. *A nivel de servicio:* El SRE ejecutó el reinicio del pool (`kubectl rollout restart deployment/sa-platform-app-transaction-service -n produccion`) retornando el error rate 5xx a 0.0% y restableciendo el SLI de disponibilidad al 99.9%.

---

## 6. 🔔 Análisis de Alerta Faltante o Sobrante

* **Alerta Faltante (Oportunidad de Mejora):**  
  Faltaba una alerta de saturación temprana sobre el **Pool de Conexiones de PostgreSQL** (`pg_stat_activity` > 85% de capacidad). Si hubiese existido esta alerta preventiva a nivel de base de datos, el equipo de SRE habría mitigado la contención de conexiones antes de que impactara a los usuarios y consumiera presupuesto de error del servicio.
* **Alerta Sobrante (Ruido Eliminado):**  
  Se detectó que una alerta heredada de tipo umbral instantáneo (`HighCPUUsage > 80% durante 30s`) se disparó durante el calentamiento del pod sin que existiera degradación alguna en la latencia ni en la tasa de errores de los usuarios. Esta alerta fue suprimida por constituir **ruido operativo**, privilegiando el monitoreo basado en consumo de presupuesto de error (Error Budget Burn Rate) que solo alerta cuando los usuarios realmente sufren el impacto.
