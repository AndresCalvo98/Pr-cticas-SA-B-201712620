# Runbook de Operación: HighErrorBudgetBurnRate_1h

**Alerta:** `HighErrorBudgetBurnRate_1h`  
**Severidad:** Crítica (Página inmediata a guardia SRE)  
**SLO Impactado:** Disponibilidad del Sistema (Objetivo: 99.0% en ventana mensual)  
**Métrica / Expresión:** `(sli:error_budget_burn_rate:1h > 14.4) and (sli:error_budget_burn_rate:5m > 14.4)`  
**Significado Operativo:** La tasa de fallo actual consumirá el **2% de todo el presupuesto mensual de error en apenas 1 hora** (equivalente a agotar el 100% en menos de 2 días).

---

## 1. Evaluación Inicial y Triage (< 2 minutos)
1. **Abrir Tablero de Operación:**
   Acceder a Grafana: `http://grafana.observabilidad.svc.cluster.local` -> Tablero `Tablero de Operación SRE - Cuatro Señales de Oro`.
2. **Revisar Señal de Errores (Error Rate 5xx):**
   Identificar cuál de los microservicios (`sa-api-gateway`, `sa-auth-service`, `sa-transaction-service`) presenta el incremento abrupto de 5xx.
3. **Verificar Tráfico de Despliegue Reciente:**
   Comprobar si hay un despliegue canary en curso en Argo Rollouts:
   ```bash
   kubectl argo rollouts get rollout sa-platform-app-transaction-service -n produccion
   ```

---

## 2. Recorrido del Síntoma a la Causa
1. **Inspeccionar Trazas en Tempo:**
   - Filtrar en Tempo por `http.status_code >= 500`.
   - Copiar el `trace_id` del span raíz con fallo.
2. **Consultar Registros en Loki con `trace_id`:**
   - En Grafana Explore (Loki):
     ```logql
     {service=~"sa-.*"} |= "<TRACE_ID>"
     ```
   - Identificar el mensaje de error exacto y el stack trace.
3. **Comprobar Conectividad con Dependencias:**
   - PostgreSQL (`sa-platform-app-postgresql:5432`):
     ```bash
     kubectl get pods -n produccion -l app.kubernetes.io/name=postgresql
     ```
   - RabbitMQ (`sa-platform-app-rabbitmq:5672`):
     ```bash
     kubectl get pods -n produccion -l app.kubernetes.io/name=rabbitmq
     ```

---

## 3. Procedimiento de Mitigación Inmediata
* **Si el fallo es ocasionado por una versión candidata (Canary):**
  Abortar inmediatamente el rollout para revertir el tráfico a la versión estable:
  ```bash
  kubectl argo rollouts abort sa-platform-app-transaction-service -n produccion
  ```
* **Si el fallo es saturación o pérdida de pods:**
  Escalar temporalmente las réplicas del servicio afectado:
  ```bash
  kubectl scale deployment <deployment-name> -n produccion --replicas=4
  ```
* **Si el fallo es pérdida de conexión con PostgreSQL:**
  Reiniciar el pod del StatefulSet:
  ```bash
  kubectl delete pod sa-platform-app-postgresql-0 -n produccion
  ```

---

## 4. Validación de Recuperación y Cierre
1. Confirmar en Grafana que `Error Rate 5xx` regresa a 0.0%.
2. Confirmar que `sli:disponibilidad:ratio_rate5m` vuelve a superar el 99.0%.
3. Registrar el incidente en el informe de post-mortem indicando RTO de mitigación y presupuesto de error residual consumido.
