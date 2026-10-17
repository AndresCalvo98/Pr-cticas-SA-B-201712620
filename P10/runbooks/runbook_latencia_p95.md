# Runbook de Operación: HighLatencyP95_5m

**Alerta:** `HighLatencyP95_5m`  
**Severidad:** Warning / Media  
**SLO Impactado:** Latencia de Respuesta (Objetivo: p95 ≤ 500ms en ventana mensual)  
**Métrica / Expresión:** `sli:latencia:p95_rate5m > 0.500`  
**Significado Operativo:** Más del 5% de las solicitudes de los usuarios están tardando más de medio segundo en responder durante una ventana sostenida de 5 minutos.

---

## 1. Diagnóstico de Causa Raíz
1. **Inspección de Cuello de Botella con Tempo:**
   - Buscar spans con duración `> 400ms`.
   - Analizar el desglose de tiempo:
     * ¿Tiempo en API Gateway?
     * ¿Tiempo en base de datos PostgreSQL (`SELECT`/`INSERT`)?
     * ¿Tiempo de encolamiento en RabbitMQ?
2. **Inspección de Saturación de Nodo:**
   - Verificar si los nodos de Kubernetes están bajo presión de CPU o I/O:
     ```bash
     kubectl top nodes
     kubectl top pods -n produccion
     ```

---

## 2. Acciones de Mitigación
1. Si el cuello de botella es la base de datos:
   - Inspeccionar locks activos en PostgreSQL:
     ```bash
     kubectl exec -it sa-platform-app-postgresql-0 -n produccion -- psql -U postgres -d transacciones -c "SELECT pid, query, state, age(clock_timestamp(), query_start) FROM pg_stat_activity WHERE state != 'idle';"
     ```
2. Si el cuello de botella es saturación de pods:
   - Activar escalado manual temporal o ajustar el HPA:
     ```bash
     kubectl scale deployment sa-platform-app-transaction-service -n produccion --replicas=4
     ```
