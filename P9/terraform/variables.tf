variable "resource_group_name" {
  description = "Nombre del Resource Group en Azure"
  type        = string
  default     = "rg-sa-p9-dr"
}

variable "location" {
  description = "Región de Azure para los recursos"
  type        = string
  default     = "eastus"
}

variable "cluster_name" {
  description = "Nombre del clúster AKS"
  type        = string
  default     = "aks-sa-p9-cluster"
}

variable "dns_prefix" {
  description = "Prefijo DNS para el clúster AKS"
  type        = string
  default     = "aks-sa-p9-dns"
}

variable "node_count" {
  description = "Número inicial de nodos worker (mínimo 2 para prueba de pérdida de nodo)"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Tamaño de las máquinas virtuales para los nodos (x86_64)"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "gitops_repo_url" {
  description = "URL del repositorio GitOps"
  type        = string
  default     = "https://github.com/AndresCalvo98/software-avanzado-gitops.git"
}

variable "gitops_branch" {
  description = "Rama objetivo en el repositorio GitOps"
  type        = string
  default     = "main"
}
