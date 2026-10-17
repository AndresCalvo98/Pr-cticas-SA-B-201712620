variable "region" {
  description = "Región de OCI"
  type        = string
  default     = "us-ashburn-1"
}

variable "cluster_name" {
  description = "Nombre del clúster OKE"
  type        = string
  default     = "oke-sa-p9-cluster"
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
