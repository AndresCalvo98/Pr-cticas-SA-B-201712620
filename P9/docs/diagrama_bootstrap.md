# 📐 Diagrama del Bootstrap de Día Cero y Dependencias de Reconstrucción

**Universidad San Carlos de Guatemala — Facultad de Ingeniería**  
**Escuela de Ciencias y Sistemas — Sistemas Avanzados (2S 2026)**  
**Carnet:** 201712620 | **Estudiante:** Luis Andres Calvo

---

## 1. Orden de Reconstrucción y Dependencias entre Componentes

El proceso de **Bootstrap de Día Cero** garantiza la recuperación total del entorno ante un desastre catastrófico a partir de un único punto de entrada (`P9/bootstrap.sh`).

A continuación se ilustra la arquitectura de reconstrucción, diferenciando con claridad las acciones **automáticas** (ejecutadas por Terraform, scripts y ArgoCD) de las acciones **manuales** iniciales (disparar el script de entrada y proveer credenciales).

```mermaid
flowchart TD
    classDef manual fill:#e65100,stroke:#fff,stroke-width:2px,color:#fff;
    classDef auto fill:#1565c0,stroke:#fff,stroke-width:2px,color:#fff;
    classDef storage fill:#2e7d32,stroke:#fff,stroke-width:2px,color:#fff;
    classDef k8s fill:#6a1b9a,stroke:#fff,stroke-width:2px,color:#fff;

    Start([Operador ejecuta ./bootstrap.sh]):::manual --> CheckPreReq[1. Verificación de CLI: az, terraform, kubectl, helm]:::auto

    subgraph Phase1 ["Fase 1: Infraestructura Base (Terraform)"]
        CheckPreReq --> TFInit[2. terraform init\nConecta al Backend Remoto]:::auto
        TFInit -.->|Lee y Bloquea State| RemoteState[(Azure Blob Storage\ntfstate / lease lock)]:::storage
        TFInit --> TFApply[3. terraform apply -auto-approve]:::auto
        TFApply --> ProvisionAKS[Aprovisiona Clúster AKS\n2 Nodos Workers - Standard_D2s_v5]:::auto
    end

    subgraph Phase2 ["Fase 2: Componentes Core del Clúster (Helm)"]
        ProvisionAKS --> InstallArgo[4. Instala ArgoCD Server\nNamespace: argocd]:::k8s
        ProvisionAKS --> InstallSealed[5. Instala Sealed Secrets Controller\nNamespace: kube-system]:::k8s
        InstallSealed --> InjectKey[6. Inyección Automática de Llave Maestra\nsealed-secrets-key-p9]:::auto
        InjectKey -.->|Restaura Clave Privada RSA| KeyFile[(secrets/sealed-secrets-key.yaml)]:::storage
    end

    subgraph Phase3 ["Fase 3: GitOps y Patrón App-of-Apps"]
        InstallArgo --> DeployRootApp[7. Despliegue de Aplicación Raíz\nsa-platform-root-app]:::k8s
        DeployRootApp -.->|Lee manifiestos Git| GitRepo[(Repositorio GitOps\nsoftware-avanzado-gitops)]:::storage
        DeployRootApp --> ChildApps[8. ArgoCD sincroniza Apps Hijas\nsa-platform-app]:::k8s
    end

    subgraph Phase4 ["Fase 4: Cargas de Trabajo y Persistencia"]
        ChildApps --> DeployDB[PostgreSQL con PVC\nDisco Administrado Azure]:::k8s
        ChildApps --> DeploySecrets[SealedSecrets Descifrados\nsa-platform-secrets]:::k8s
        ChildApps --> DeployMicroservices[Microservicios con 2 Réplicas\nPDB minAvailable:1 + podAntiAffinity]:::k8s
        ChildApps --> DeployIngress[Ingress + RabbitMQ]:::k8s
    end

    subgraph Phase5 ["Fase 5: Validación y Salud"]
        DeployDB --> WaitHealth[9. kubectl wait --condition=ready pods]:::auto
        DeployMicroservices --> WaitHealth
        WaitHealth --> Ready([Sistema 100% Recuperado y Operativo]):::manual
    end
```

---

## 2. Clasificación de Tareas: Automático vs. Manual

| Componente / Paso | Tipo de Ejecución | Responsable | Mecanismo de Control |
|---|---|---|---|
| **Disparo del proceso** | 🟠 **Manual** | Operador SRE | Ejecución de `./bootstrap.sh` |
| **Bloqueo y lectura de estado** | 🔵 **Automático** | Terraform | Backend remoto `azurerm` con Lease Locking |
| **Aprovisionamiento de AKS** | 🔵 **Automático** | Terraform | Provider AzureRM |
| **Instalación de ArgoCD** | 🔵 **Automático** | Terraform / Helm | Helm Release `argo-cd` |
| **Instalación de Sealed Secrets** | 🔵 **Automático** | Terraform / Helm | Helm Release `sealed-secrets` |
| **Restauración de clave de secretos** | 🔵 **Automático** | `bootstrap.sh` | Inyección de Secret con etiquetas de Bitnami |
| **Despliegue de App-of-Apps** | 🔵 **Automático** | Terraform / Helm | Helm Release `root-app` |
| **Sincronización de Microservicios** | 🔵 **Automático** | ArgoCD | Auto-sync con `prune` y `selfHeal` |
| **Verificación de disponibilidad** | 🔵 **Automático** | `bootstrap.sh` | Probes de readiness y `kubectl wait` |

---

## 3. Matriz de Dependencias

1. **AKS Clúster** depende del **Resource Group** y **Red Virtual**.
2. **ArgoCD y Sealed Secrets** dependen de la disponibilidad del **API Server de Kubernetes**.
3. **Descifrado de Secretos** depende de la inyección previa de la **Llave Maestra RSA**.
4. **Microservicios (Pods)** dependen de la existencia de los **Secretos descifrados** (`sa-platform-secrets`) y la base de datos PostgreSQL.
5. **App-of-Apps** orquesta la convergencia final garantizando el orden de despliegue mediante políticas de sincronización de ArgoCD.
