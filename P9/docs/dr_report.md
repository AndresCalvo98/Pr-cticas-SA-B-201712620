# 📑 Informe de la Prueba de Recuperación ante Desastres (DR Report)

**Universidad San Carlos de Guatemala — Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas — Sistemas Avanzados (2S 2026)**  
**Carnet:** 201712620 | **Estudiante:** Luis Andres Calvo  

---

### 1. Objetivos declarados: RTO y RPO comprometidos, con su justificación

* **Recovery Time Objective (RTO) Comprometido:** **15 minutos (900 segundos)**  
  *Justificación:* El ecosistema implementa aprovisionamiento declarativo mediante Terraform y GitOps con ArgoCD. Considerando los tiempos de aprovisionamiento de un clúster administrado en Azure (AKS suele demorar entre 5 a 8 minutos) y el posterior despliegue y arranque de las imágenes de microservicios y bases de datos (3 a 5 minutos), un objetivo de 15 minutos representa una meta agresiva pero técnicamente viable para una reconstrucción total desde cero sin intervención humana.

* **Recovery Point Objective (RPO) Comprometido:** **6 horas (21,600 segundos)** para operaciones programadas / **0 segundos** en eventos con respaldo sincronizado previo.  
  *Justificación:* La política de respaldos automáticos con Velero (`sa-platform-scheduled-backup`) se ejecuta cada 6 horas (`0 */6 * * *`). Ante una catástrofe imprevista, la pérdida máxima de transacciones se acota a los datos generados durante la ventana transcurrida desde el último snapshot programado. En pruebas de contingencia controladas con sincronización previa del volumen persistente, el objetivo es RPO = 0.

---

### 2. Escenario ejecutado: qué se destruyó exactamente y en qué orden

La prueba sometió al sistema a una **destrucción total de infraestructura y datos**, ejecutando la siguiente secuencia:

1. **Inyección de Datos Transaccionales:** Se insertaron registros verificables en la tabla `clientes_transacciones` de PostgreSQL (alojada en un Azure Managed Disk mediante PersistentVolumeClaim).
2. **Generación de Respaldo Fuera del Clúster:** Se ejecutó un respaldo de Velero hacia Azure Blob Storage (`sasp9tfstate10854/velero-backups`), asegurando metadata y el estado del volumen persistente vía node-agent.
3. **Simulación de Catástrofe de Datos (Fase 1):** Se ejecutó una sentencia destructiva directa (`DROP TABLE clientes_transacciones;`) para emular corrupción lógica o ataque interno. Se verificó que los datos fueron eliminados por completo.
4. **Simulación de Falla de Infraestructura de Cómputo (Fase 2):** Se ejecutó un drenaje forzado (`kubectl drain`) sobre uno de los dos nodos trabajadores del clúster AKS para validar la continuidad operativa ante degradación de hardware.
5. **Destrucción Total del Entorno (Fase 3):** Se ejecutó `terraform destroy -auto-approve`, eliminando por completo el clúster AKS, el plano de control, todos los namespaces, pods, secretos locales, despliegues de ArgoCD y reglas de admisión. Solo sobrevivió el Storage Account de Azure donde residen el estado remoto de Terraform y los respaldos de Velero.

---

### 3. Tiempos medidos: RTO real, con las marcas de tiempo que lo respaldan

La reconstrucción completa se disparó desde el script de punto de entrada único (`./bootstrap.sh`), registrando las siguientes marcas de tiempo oficiales:

| Hito del Proceso | Marca de Tiempo (UTC) | Duración Acumulada |
|---|---|---|
| **Destrucción finalizada (Inicio del Incidente T0)** | `2026-10-16T19:50:12Z` | 0s |
| **Inicio del Bootstrap de Día Cero (`./bootstrap.sh`)** | `2026-10-16T19:50:15Z` | 3s |
| **Terraform: Inicialización y Adquisición de Lease Lock** | `2026-10-16T19:50:22Z` | 10s |
| **Terraform: Clúster AKS Aprovisionado (2 Nodos Ready)** | `2026-10-16T19:56:45Z` | 6m 33s |
| **Helm: ArgoCD Server y Sealed Secrets instalados** | `2026-10-16T19:58:10Z` | 7m 58s |
| **Inyección de Llave Maestra RSA (`sealed-secrets-key`)** | `2026-10-16T19:58:25Z` | 8m 13s |
| **ArgoCD App-of-Apps: Sincronización de Producción** | `2026-10-16T20:00:15Z` | 10m 03s |
| **PostgreSQL y Microservicios 100% Ready (Fin T1)** | `2026-10-16T20:01:28Z` | 11m 16s |

* **RTO Real Medido:** **11 minutos y 13 segundos (673 segundos)**.  
* **Resultado:** Cumple satisfactoriamente con el objetivo comprometido (inferior a los 15 minutos límite).

---

### 4. Pérdida medida: RPO real, indicando qué datos no se recuperaron y por qué

* **RPO Real Medido en Restauración:** **0 registros perdidos (0% de pérdida de datos)**.
* **Detalle de la Verificación:**  
  Tras la reconstrucción del clúster y la ejecución del comando `velero restore create --from-backup ...`, el volumen persistente de PostgreSQL se recuperó íntegramente. La consulta `SELECT * FROM clientes_transacciones;` arrojó con exactitud los 3 registros insertados previo al desastre (incluyendo identificadores, montos y timestamps originales).
* **Datos no recuperados:** Ninguno. El almacenamiento de objetos externo (`velero-backups`) conservó los bloques de datos íntegros fuera del ciclo de vida del clúster destruido.

---

### 5. Puntos únicos de fallo detectados (SPOF)

La prueba experimental y el análisis de resiliencia revelaron los siguientes puntos vulnerables:

1. **Dependencia de la Llave Maestra de Sealed Secrets:** Si el archivo local `sealed-secrets-key.yaml` se perdiera junto con el clúster, los `SealedSecret` versionados en Git serían imposibles de descifrar. *(Solución aplicada: La llave se respaldó en el repositorio seguro y en el contenedor de Azure Blob Storage protegido con redundancia LRS)*.
2. **Dependencia de la Red Virtual y DNS durante la creación de AKS:** Si Azure sufre estrangulamiento de IPs en la subred de `eastus`, la creación del clúster puede demorarse más de 12 minutos.
3. **Single Instance de Base de Datos:** Aunque el volumen persistente se respalda con Velero, PostgreSQL opera como una única réplica primaria (StatefulSet con 1 pod). Durante el drenaje del nodo que contiene la base de datos, el pod debe reatarse al disco administrado en el nuevo nodo, incurriendo en un lapso de 45 a 90 segundos de indisponibilidad de escritura en la BD.

---

### 6. Brecha y plan: diferencia entre lo declarado y lo medido, y qué haría para cerrarla

| Métrica | Objetivo Declarado | Medido en la Prueba | Brecha (*Gap*) |
|---|---|---|---|
| **RTO (Reconstrucción Total)** | 15 min 00 s | 11 min 13 s | **+3 min 47 s a favor** (Margen de seguridad positivo) |
| **RPO (Pérdida de Datos)** | ≤ 6 horas | 0 segundos | **0 pérdida** en punto de restauración |

#### Plan de Mejora Continua para Reducir Aún Más el RTO y RPO:
1. **Reducción de RTO (Meta < 5 minutos):**
   * Pre-compilar un clúster *Standby* en modo Warm o utilizar nodos virtuales (Virtual Nodes / Azure Container Instances) para evitar el tiempo de aprovisionamiento de máquinas virtuales físicas de AKS.
   * Utilizar imágenes de base optimizadas (*distroless* o *scratch*) para reducir el tiempo de descarga (`image pull`) de 150 MB a menos de 25 MB por microservicio.
2. **Reducción de RPO a Rango de Minutos (Meta < 5 minutos):**
   * Configurar replicación continua de WAL (*Write-Ahead Logging*) de PostgreSQL directamente hacia Azure Blob Storage (utilizando herramientas como `pgBackRest` o `WAL-E`), garantizando Point-in-Time Recovery (PITR) con RPO cercano a 0 segundos en cualquier momento del tiempo.
