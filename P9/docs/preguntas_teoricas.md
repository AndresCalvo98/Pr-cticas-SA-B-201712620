# 🧠 Preguntas Teóricas y Análisis de Resiliencia del Sistema

**Universidad San Carlos de Guatemala — Facultad de Ingeniería**  
**Sistemas Avanzados (2S 2026)**  
**Carnet:** 201712620 | **Estudiante:** Luis Andres Calvo  

---

### 1. ¿Cómo se comporta el sistema si falla un nodo trabajador versus si falla el plano de control (Control Plane)?

* **Falla de un Nodo Trabajador:**  
  Gracias a la arquitectura implementada con **2 réplicas por microservicio**, reglas de **`podAntiAffinity`** y un **`PodDisruptionBudget`** con `minAvailable: 1`, la pérdida de un nodo trabajador es transparente para el usuario final. El tráfico entrante es balanceado inmediatamente hacia la réplica sobreviviente en el otro nodo, mientras el Kubelet y el Controller Manager detectan el nodo inaccesible y reprograman los pods desalojados sin tiempo de inactividad (*Zero Downtime*).
* **Falla del Plano de Control:**  
  En AKS, el plano de control (API Server, etcd, scheduler) es completamente administrado por Azure y cuenta con alta disponibilidad multi-zona nativa. Sin embargo, si el plano de control se volviera inaccesible, **los pods y cargas de trabajo en ejecución en los nodos continuarían operando y respondiendo tráfico normalmente** (el plano de datos se mantiene activo). Las limitaciones inmediatas serían la incapacidad de procesar nuevos despliegues de ArgoCD, ejecutar autoescalado de réplicas (HPA) o reagrupar pods si ocurriera una falla adicional en un nodo de trabajo.

---

### 2. ¿Cuáles son los límites de Velero como solución de respaldo frente a una solución de replicación activa-activa?

* **Límites de Velero:**  
  Velero opera mediante respaldos periódicos discretos (*snapshots* puntuales y copias de seguridad de metadatos/volúmenes). Su RPO está intrínsecamente delimitado por la frecuencia del cronograma (ej. 6 horas). Cualquier transacción producida entre el último respaldo y el instante del desastre se perderá irreversiblemente. Además, la recuperación con Velero es reactiva y requiere un tiempo de ejecución (RTO) para restaurar los bloques de almacenamiento y sincronizar los pods.
* **Frente a Activa-Activa:**  
  Una arquitectura Activa-Activa (con bases de datos distribuidas como CockroachDB o replicación síncrona de PostgreSQL en clústeres multi-región) ofrece RTO ≈ 0 y RPO ≈ 0, permitiendo conmutación por error (*failover*) instantánea y sin pérdida de datos. No obstante, una solución activa-activa introduce una sobrecarga considerable en latencia de red de escritura, mayor complejidad operativa y costos de infraestructura significativamente superiores a la estrategia con Velero y GitOps.

---

### 3. ¿Por qué es fundamental la combinación de PodDisruptionBudget y podAntiAffinity durante el mantenimiento del clúster?

El mantenimiento de nodos (como una actualización de versión de Kubernetes mediante `kubectl drain`) requiere desalojar (*evict*) las cargas de trabajo de una máquina:
* Si únicamente tuviéramos **2 réplicas** pero **sin `podAntiAffinity`**, el planificador de Kubernetes podría ubicar ambas réplicas en el mismo nodo. Al drenar ese nodo, el servicio caería al 100%.
* Si tuviéramos **`podAntiAffinity`** pero **sin `PodDisruptionBudget`**, el comando `kubectl drain` podría eliminar todas las réplicas en paralelo si ambas máquinas se actualizaran o reiniciaran simultáneamente.
* **La combinación sinérgica:** `podAntiAffinity` garantiza que las réplicas estén físicamente separadas en hosts distintos, y el `PodDisruptionBudget` (`minAvailable: 1`) le impone una regla inviolable a Kubernetes: *nunca desaloje un pod si con ello deja menos de 1 pod saludable atendiendo tráfico*. Esto garantiza la continuidad operativa absoluta durante cualquier intervención.

---

### 4. ¿Qué ventajas y desventajas presenta Sealed Secrets frente a External Secrets Operator (ESO) con Azure Key Vault?

| Característica | Sealed Secrets (Bitnami) | External Secrets Operator (ESO) |
|---|---|---|
| **Almacenamiento del Secreto** | Cifrado asimétrico dentro del repositorio Git | Almacenado externamente en Azure Key Vault |
| **Punto Único de Fallo** | Dependencia crítica de la llave privada del clúster | Dependencia del servicio externo de Azure Key Vault y conectividad de red |
| **Ciclo de Vida / Rotación** | Requiere re-cifrar con la nueva clave pública y hacer commit | Se actualiza en Key Vault y se sincroniza automáticamente en K8s |
| **Independencia de la Nube** | **100% agnóstico** a la nube (corre en cualquier Kubernetes) | Vinculado a las APIs de identidad (Workload Identity) del proveedor cloud |
| **Recuperabilidad ante DR** | Rápida si la clave maestra está respaldada | Excelente porque los secretos residen fuera del clúster destruido |

---

### 5. ¿Qué sucedería si se pierde o corrompe el backend remoto de Terraform (`terraform.tfstate`)?

El archivo de estado (`tfstate`) es el mapa que vincula el código declarativo con los identificadores reales de los recursos aprovisionados en Azure (ID del clúster, IPs, subredes).
* Si el estado remoto se destruye o corrompe, Terraform pierde la noción de qué recursos existen. Al ejecutar un nuevo `terraform apply`, intentará crearlos de nuevo, provocando conflictos de colisión de nombres (ej. `Resource already exists`).
* **Mecanismos de Protección Implementados:**  
  1. El Storage Account de Azure tiene habilitado **bloqueo de estado (*lease locking*)** para impedir corrupciones por escrituras concurrentes.
  2. En Azure Blob Storage se puede activar el **versionamiento de blobs** y el **Soft Delete**, lo que permite restaurar una versión anterior del archivo `.tfstate` ante borrados accidentales en cuestión de segundos.
  3. En el peor escenario de pérdida total del `.tfstate`, el enfoque de **Bootstrap de Día Cero** permite recrear la infraestructura limpia en un nuevo grupo de recursos sin requerir el estado antiguo.
