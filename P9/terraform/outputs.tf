output "oke_cluster_name" {
  description = "Nombre del clúster de Kubernetes en OCI"
  value       = var.cluster_name
}

output "argocd_root_app_name" {
  description = "Nombre de la aplicación raíz App-of-Apps en ArgoCD"
  value       = helm_release.root_app.name
}
