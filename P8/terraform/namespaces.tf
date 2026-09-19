resource "kubernetes_namespace" "produccion" {
  metadata {
    name = "produccion"
  }
}
