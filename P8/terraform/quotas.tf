resource "kubernetes_resource_quota" "produccion_quota" {
  metadata {
    name      = "produccion-quota"
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
      "limits.cpu"      = "4"
      "limits.memory"   = "4Gi"
      "pods"            = "30"
    }
  }
}

resource "kubernetes_limit_range" "produccion_limits" {
  metadata {
    name      = "produccion-limits"
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = "500m"
        memory = "512Mi"
      }
      default_request = {
        cpu    = "250m"
        memory = "256Mi"
      }
    }
  }
}
