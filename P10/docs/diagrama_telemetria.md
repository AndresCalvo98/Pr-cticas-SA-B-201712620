# 📐 Diagrama del Flujo de Telemetría (Criterio 1.3 - 6 pts)

**Universidad de San Carlos de Guatemala — Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas — Sistemas Avanzados (Segundo Semestre 2026)**  
**Estudiante:** Luis Andres Calvo Arreaga | **Carnet:** `201712620`  
**Práctica 10:** Observabilidad y Operación  

---

## 🔄 Flujo Integral de Señales: Del Microservicio al Tablero y a la Alerta

```mermaid
flowchart TD
    subgraph Microservicios ["Microservicios Instrumentados (Namespace: produccion)"]
        GW["sa-api-gateway\n(Node.js OTel SDK)"]
        AUTH["sa-auth-service\n(Node.js OTel SDK)"]
        TX["sa-transaction-service\n(Node.js / Go OTel SDK)"]
        
        GW -->|W3C traceparent\nHTTP Header| AUTH
        GW -->|W3C traceparent\nHTTP Header| TX
    end

    subgraph TelemetryCollection ["Plano de Ingesta y Recolección"]
        OTEL["OpenTelemetry Collector\n(OTLP gRPC :4317 / HTTP :4318)"]
        PROM_SCRAPE["Prometheus Scraper\n(Intervalo: 5s /metrics)"]
    end

    GW -.->|OTLP Traces| OTEL
    AUTH -.->|OTLP Traces| OTEL
    TX -.->|OTLP Traces| OTEL

    GW -.->|Scrape /metrics| PROM_SCRAPE
    AUTH -.->|Scrape /metrics| PROM_SCRAPE
    TX -.->|Scrape /metrics| PROM_SCRAPE
    TX -.->|Stdout JSON Logs\ncon trace_id| KUBELET["Kubelet Container Engine\n(/var/log/pods)"]

    subgraph StorageBackends ["Almacenes de Observabilidad (Namespace: observabilidad)"]
        TEMPO["Grafana Tempo\n(Backend de Trazas OTLP :3200)"]
        LOKI["Grafana Loki\n(Almacén de Registros :3100)"]
        PROM["Prometheus TSDB\n(Métricas & Recording Rules :9090)"]
    end

    OTEL -->|Export Traces| TEMPO
    KUBELET -->|Promtail / Fluent / Daemon| LOKI
    PROM_SCRAPE --> PROM

    subgraph OperationsAndActions ["Operación, Visualización y Gobernanza"]
        GRAFANA["Grafana (Puerto 80)\nTablero 4 Señales de Oro\n(Latencia, Tráfico, Errores, Saturación)"]
        ALERT["Alertmanager\nAlertas Multi-Ventana de Presupuesto\n(14.4x 1h / 6x 6h)"]
        ROLLOUT["Argo Rollouts Controller\n(AnalysisTemplate por Métricas PromQL)"]
        SRE["Ingeniero de Guardia (Staff SRE)\nAtención con Runbooks en < 3 min"]
    end

    PROM -->|Datasource| GRAFANA
    LOKI -->|Datasource| GRAFANA
    TEMPO -->|Datasource| GRAFANA

    TEMPO -.->|Trace-to-Logs Correlator\ntrace_id| LOKI

    PROM -->|Disparo de Alertas| ALERT
    ALERT -->|Notificación + Runbook URL| SRE
    GRAFANA -.->|Consulta de Diagnóstico| SRE

    PROM -->|Evaluación Canary en Vivo| ROLLOUT
    ROLLOUT -.->|Abort / Reversión Automática\nsi Error Rate > 1%| TX
```

---

## 📌 Descripción de los Componentes

1. **Propagación de Contexto W3C (`traceparent`):**  
   Garantiza que toda la cadena de llamadas desde el Gateway hasta los servicios internos comparta un único `trace_id` inmutable.
2. **OpenTelemetry Collector Contrib:**  
   Recibe trazas vía OTLP gRPC/HTTP, aplica limitación de memoria y las reenvía a Grafana Tempo.
3. **Prometheus TSDB:**  
   Recolecta métricas cada 5 segundos y ejecuta las `PrometheusRule` (SLIs de disponibilidad y latencia $p95$, junto a las alertas multi-ventana por consumo de presupuesto de error).
4. **Grafana Loki & Tempo Correlator:**  
   Permite pasar en un solo clic desde la traza fallida en Tempo al registro exacto en formato JSON en Loki usando el `trace_id`.
5. **Argo Rollouts Canary Analysis:**  
   Consulta directamente la API de Prometheus en cada paso de promoción; si el percentil de latencia o la tasa de 5xx del canary supera el límite, aborta el despliegue sin intervención manual.
