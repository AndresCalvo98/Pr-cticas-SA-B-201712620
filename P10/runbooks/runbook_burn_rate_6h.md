# Runbook de Operación: HighErrorBudgetBurnRate_6h

**Alerta:** `HighErrorBudgetBurnRate_6h`  
**Severidad:** Warning / Media (Notificación a canal de guardia en horario hábil)  
**SLO Impactado:** Disponibilidad del Sistema (Objetivo: 99.0% en ventana mensual)  
**Métrica / Expresión:** `(sli:error_budget_burn_rate:6h > 6.0) and (sli:error_budget_burn_rate:30m > 6.0)`  
**Significado Operativo:** La degradación sostenida consumirá el **5% del presupuesto mensual en 6 horas** (agotamiento total en ~5 días).

---

## 1. Contexto y Diagnóstico
Esta alerta detecta fallos silenciosos, degradaciones progresivas de APIs externas, o errores intermitentes en llamadas a base de datos que no alcanzan a disparar la alerta de 1h pero comprometen la fiabilidad a medio plazo.

1. **Revisar Errores por Servicio en Tablero Grafana:**
   Identificar si el fallo está concentrado en una ruta específica (e.g. `/api/transactions/process`).
2. **Consultar Volumen de Pagos Rechazados (`pagos_rechazados_total`):**
   Determinar si la degradación se origina en validaciones de negocio o fallos 5xx del backend.

---

## 2. Acciones de Mitigación
1. Revisar logs agregados en Loki para detectar excepciones intermitentes:
   ```logql
   {namespace="produccion"} |= "level=ERROR" or |= "\"level\":\"ERROR\""
   ```
2. Si un microservicio presenta fuga de memoria o incremento de CPU:
   Ejecutar reinicio gradual de sus réplicas:
   ```bash
   kubectl rollout restart deployment/sa-platform-app-auth-service -n produccion
   ```
3. Verificar si el pool de conexiones a la base de datos se encuentra saturado.
