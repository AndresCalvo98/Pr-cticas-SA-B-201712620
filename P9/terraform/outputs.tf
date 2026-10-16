output "resource_group_name" {
  description = "Nombre del Resource Group"
  value       = data.azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "Nombre del clúster AKS"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_node_count" {
  description = "Número de nodos trabajadores aprovisionados"
  value       = azurerm_kubernetes_cluster.aks.default_node_pool[0].node_count
}

output "aks_kubeconfig_command" {
  description = "Comando para obtener credenciales de kubectl"
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}

output "argocd_root_app_name" {
  description = "Nombre de la aplicación raíz del patrón app-of-apps"
  value       = "sa-platform-root-app"
}
