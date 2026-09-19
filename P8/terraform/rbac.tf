resource "kubernetes_service_account" "github_actions" {
  metadata {
    name      = "github-actions-sa"
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }
}

resource "kubernetes_role" "deployer_role" {
  metadata {
    name      = "deployer-role"
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }

  rule {
    api_groups = ["", "apps", "batch", "extensions"]
    resources  = ["deployments", "services", "pods", "cronjobs", "configmaps", "secrets", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding" "deployer_binding" {
  metadata {
    name      = "deployer-binding"
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.deployer_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions.metadata[0].name
    namespace = kubernetes_namespace.produccion.metadata[0].name
  }
}
