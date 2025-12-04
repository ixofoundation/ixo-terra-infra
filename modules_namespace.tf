resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_namespace_v1" "redis" {
  metadata {
    name = "redis"
  }
}

resource "kubernetes_namespace_v1" "postgres_operator" {
  metadata {
    name = "postgres-operator"
  }
}

resource "kubernetes_namespace_v1" "prometheus_stack" {
  metadata {
    name = "prometheus"
  }
}

resource "kubernetes_namespace_v1" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

resource "kubernetes_namespace_v1" "dex" {
  metadata {
    name = "dex"
  }
}

resource "kubernetes_namespace_v1" "vault" {
  metadata {
    name = "vault"
  }
}

resource "kubernetes_namespace_v1" "loki" {
  metadata {
    name = "loki"
  }
}

resource "kubernetes_namespace_v1" "prometheus_blackbox_exporter" {
  metadata {
    name = "prometheus-blackbox-exporter"
  }
}

resource "kubernetes_namespace_v1" "tailscale" {
  metadata {
    name = "tailscale"
  }
}

resource "kubernetes_namespace_v1" "matrix" {
  metadata {
    name = var.pg_matrix.namespace
  }
}

resource "kubernetes_namespace_v1" "nfs_provisioner" {
  metadata {
    name = "nfs"
  }
}

resource "kubernetes_namespace_v1" "metrics_server" {
  metadata {
    name = "metrics-server"
  }
}

resource "kubernetes_namespace_v1" "uptime_kuma" {
  metadata {
    name = "uptime-kuma"
  }
}

resource "kubernetes_namespace_v1" "chromadb" {
  metadata {
    name = "chromadb"
  }
}

resource "kubernetes_namespace_v1" "ghost" {
  metadata {
    name = "ghost"
  }
}

resource "kubernetes_namespace_v1" "neo4j" {
  metadata {
    name = "neo4j"
  }
}

resource "kubernetes_namespace_v1" "matrix_livekit" {
  metadata {
    name = "matrix-livekit"
  }
}

resource "kubernetes_namespace_v1" "falco_security" {
  metadata {
    name = "falco-security"
  }
}

resource "kubernetes_namespace_v1" "surrealdb" {
  metadata {
    name = "surrealdb"
  }
}

resource "kubernetes_namespace_v1" "descheduler" {
  metadata {
    name = "descheduler"
  }
}