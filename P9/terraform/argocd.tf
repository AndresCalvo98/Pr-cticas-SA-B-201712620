# 1. Instalación de ArgoCD mediante Helm
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.insecure"
    value = "true"
  }

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "crds.install"
    value = "true"
  }
}

# 2. Despliegue de la Aplicación Raíz (App-of-Apps)
resource "helm_release" "root_app" {
  name       = "sa-platform-root-app"
  chart      = "${path.module}/root-chart"
  namespace  = "argocd"

  set {
    name  = "repoURL"
    value = var.gitops_repo_url
  }

  set {
    name  = "targetRevision"
    value = var.gitops_branch
  }

  depends_on = [
    helm_release.argocd
  ]
}
