resource "helm_release" "docker-gc" {
  name = "docker-gc"
  chart = "stable/spotify-docker-gc"
}

resource "helm_release" "dashboard" {
  name = "dashboard"
  chart = "stable/kubernetes-dashboard"

  set {
    name = "rbac.create"
    value = "true"
  }
}

resource "helm_release" "prometheus" {
  name = "prometheus"
  chart = "stable/prometheus"

  set {
    name = "rbac.create"
    value = "true"
  }
}
