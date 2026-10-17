# 🧠 Respuestas y Análisis de Preguntas Teóricas (Criterio 1.4 - 10 pts)

**Universidad de San Carlos de Guatemala — Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas — Sistemas Avanzados (Segundo Semestre 2026)**  
**Estudiante:** Luis Andres Calvo Arreaga | **Carnet:** `201712620`  
**Práctica 10:** Observabilidad y Operación  

---

### Pregunta 1: ¿Por qué las alertas basadas en umbrales instantáneos generan fatiga de alertas y cómo el cálculo multi-ventana de quema de presupuesto de error (Multi-Window Multi-Burn-Rate) resuelve este problema?

**Análisis y Respuesta:**
Las alertas tradicionales basadas en umbrales estáticos e instantáneos (por ejemplo, `CPU > 80% durante 1m` o `Error Rate > 1% durante 30s`) sufren de dos patologías graves en sistemas de producción:
1. **Falsos Positivos (Fatiga de Alertas):** Picos transitorios generados por procesos de arranque, recolectores de basura (GC) o tareas programadas superan brevemente el umbral y despiertan al ingeniero de guardia sin representar ningún daño real a la experiencia de usuario.
2. **Falsos Negativos:** Un fallo de bajo volumen pero constante (por ejemplo, 0.8% de errores continuos) no alcanza el umbral de 1%, pero en cuestión de días consume la totalidad del presupuesto de error del servicio.

El enfoque propuesto por Google SRE de **Multi-Window Multi-Burn-Rate** resuelve ambas fallas:
* Evalúa la **velocidad de consumo** (burn rate) con respecto al presupuesto de error tolerado. Por ejemplo, un burn rate de $14.4\times$ significa que el servicio agotará el 2% de su presupuesto mensual en tan solo 1 hora.
* Aplica **ventanas cruzadas de validación**: exige que la quema acelerada ocurra simultáneamente en una ventana larga (ej. 1 hora) y en una ventana corta (ej. 5 minutos). Esto garantiza que la alerta solo se dispare si el problema no solo fue severo en la última hora, sino que **sigue activo en este preciso instante**, eliminando el 100% de los falsos positivos por picos transitorios ya resueltos.

---

### Pregunta 2: ¿Cómo interactúan el contexto de traza W3C (`traceparent`) y el enriquecimiento de registros (Log Correlator) para permitir el salto directo entre métricas, trazas y logs?

**Análisis y Respuesta:**
En arquitecturas de microservicios, una sola petición de usuario se fragmenta en múltiples saltos HTTP y asíncronos. La interacción se basa en la especificación estándar **W3C TraceContext**:
1. **Propagación:** El API Gateway genera o recibe el encabezado HTTP `traceparent` (compuesto por `version-trace_id-parent_id-trace_flags`). Cada microservicio downstream extrae (`propagation.extract`) este contexto y lo inyecta (`propagation.inject`) en sus llamadas subsiguientes. Esto garantiza que todos los eventos compartan exactamente el mismo `trace_id` de 128 bits a lo largo de toda la topología.
2. **Enriquecimiento de Registros:** Al emitir registros en la aplicación, el logger consulta el span activo en el contexto local (`opentelemetry.trace.getActiveSpan()`) e incrusta el `trace_id` y `span_id` directamente como campos de primer nivel en el payload JSON.
3. **Correlación Bidireccional:**
   * *De la Métrica a la Traza:* Un panel en Grafana que detecta un percentil alto ($p95$) enlaza automáticamente a Tempo filtrando trazas en ese rango temporal.
   * *De la Traza al Log:* Grafana Tempo dispone de la función `tracesToLogs`, que mediante la regla `{service=~"sa-.*"} |= "${__trace.id}"` consulta en Loki todos los registros que compartan ese identificador, mostrando la causa raíz exacta sin necesidad de búsquedas manuales por texto libre.

---

### Pregunta 3: ¿Cuáles son las limitaciones prácticas y de sobrecarga (overhead) de OpenTelemetry en entornos de alta concurrencia y qué estrategias de muestreo (Sampling) deben implementarse?

**Análisis y Respuesta:**
En entornos con miles de peticiones por segundo, instrumentar el 100% de las trazas genera tres cuellos de botella:
* **Overhead en CPU y Memoria:** Serialización continua de spans, creación de objetos en el heap y retención en buffers de memoria antes del envío.
* **Saturación de Red:** Transmisión de miles de payloads OTLP hacia el Collector y los backends de almacenamiento.
* **Costes de Almacenamiento:** Indexación y retención de peticiones en Tempo/Jaeger que resultaron ser un `200 OK` idéntico y carente de valor diagnóstico.

**Estrategias de Mitigación:**
1. **Head-Based Sampling:** La decisión de muestreo se toma al inicio de la petición (en el API Gateway) mediante un algoritmo probabilístico (ej. muestrear el 5% del tráfico). Es computacionalmente liviano, pero corre el riesgo de no capturar errores infrecuentes.
2. **Tail-Based Sampling (Recomendada):** El OpenTelemetry Collector retiene todos los spans de una traza en memoria hasta que esta finaliza. Si la traza contiene un span con `http.status_code >= 500` o una duración superior a la cota del SLO ($> 500\text{ ms}$), la traza se almacena al 100%; de lo contrario, se descarta. Esto maximiza la densidad de información útil retenida minimizando el costo de almacenamiento.
