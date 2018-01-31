resource "helm_release" "dashboard" {
  name = "dashboard"
  chart = "stable/kubernetes-dashboard"

  set {
    name = "rbac.create"
    value = true
  }
}
