locals {
  jupyterlite-prefix = "jupyterlite"
  overrides          = jsondecode(var.overrides)
  has_content_repo   = var.content-repo != ""
}

# Deployment ===================================================================
resource "kubernetes_deployment" "jupyterlite" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "jupyterlite"
    namespace = var.namespace
    labels = {
      app = "jupyterlite"
    }
  }

  spec {
    replicas = lookup(local.overrides, "replicas", 1)

    selector {
      match_labels = {
        app = "jupyterlite"
      }
    }

    template {
      metadata {
        labels = {
          app = "jupyterlite"
        }
      }

      spec {
        # Init container to clone repo and generate index (only if content_repo is set)
        dynamic "init_container" {
          for_each = local.has_content_repo ? [1] : []
          content {
            name  = "content-loader"
            image = "python:3.12-alpine"

            command = ["/bin/sh", "-c"]
            args = [<<-EOT
              set -e
              apk add --no-cache git
              echo "Cloning ${var.content-repo} (branch: ${var.content-branch})..."
              git clone --depth 1 --branch ${var.content-branch} ${var.content-repo} /tmp/content

              echo "Generating content index..."
              python3 /scripts/generate_index.py /tmp/content /output

              echo "Content loaded successfully."
            EOT
            ]

            volume_mount {
              name       = "content-output"
              mount_path = "/output"
            }

            volume_mount {
              name       = "scripts"
              mount_path = "/scripts"
            }
          }
        }

        container {
          name  = "jupyterlite"
          image = lookup(local.overrides, "image", "quay.io/nebari/nebari-jupyterlite-plugin:latest")

          port {
            container_port = 8000
          }

          # Mount content output if content_repo is set
          dynamic "volume_mount" {
            for_each = local.has_content_repo ? [1] : []
            content {
              name       = "content-output"
              mount_path = "/usr/share/nginx/html/files"
              sub_path   = "files"
            }
          }

          dynamic "volume_mount" {
            for_each = local.has_content_repo ? [1] : []
            content {
              name       = "content-output"
              mount_path = "/usr/share/nginx/html/api/contents/all.json"
              sub_path   = "api/contents/all.json"
            }
          }

          resources {
            requests = {
              cpu    = lookup(lookup(local.overrides, "resources", {}), "cpu_request", "100m")
              memory = lookup(lookup(local.overrides, "resources", {}), "memory_request", "128Mi")
            }
            limits = {
              cpu    = lookup(lookup(local.overrides, "resources", {}), "cpu_limit", "500m")
              memory = lookup(lookup(local.overrides, "resources", {}), "memory_limit", "256Mi")
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8000
            }
            initial_delay_seconds = 10
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }

        # Volumes
        dynamic "volume" {
          for_each = local.has_content_repo ? [1] : []
          content {
            name = "content-output"
            empty_dir {}
          }
        }

        dynamic "volume" {
          for_each = local.has_content_repo ? [1] : []
          content {
            name = "scripts"
            config_map {
              name = kubernetes_config_map.generate_index_script[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

# ConfigMap for generate_index.py script
resource "kubernetes_config_map" "generate_index_script" {
  count = var.enabled && local.has_content_repo ? 1 : 0

  metadata {
    name      = "jupyterlite-scripts"
    namespace = var.namespace
  }

  data = {
    "generate_index.py" = file("${path.module}/scripts/generate_index.py")
  }
}

# Service ======================================================================
resource "kubernetes_service" "jupyterlite" {
  count = var.enabled ? 1 : 0

  metadata {
    name      = "jupyterlite"
    namespace = var.namespace
    labels = {
      app = "jupyterlite"
    }
  }

  spec {
    selector = {
      app = "jupyterlite"
    }

    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# Routing ======================================================================
resource "kubernetes_manifest" "jupyterlite-middleware-stripprefix" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "jupyterlite-stripprefix"
      namespace = var.namespace
    }
    spec = {
      stripPrefix = {
        prefixes = [
          "/${local.jupyterlite-prefix}"
        ]
        forceSlash = false
      }
    }
  }
}

resource "kubernetes_manifest" "jupyterlite-add-slash" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "jupyterlite-add-slash"
      namespace = var.namespace
    }
    spec = {
      redirectRegex = {
        regex       = "^https://${var.external_url}/${local.jupyterlite-prefix}$"
        replacement = "https://${var.external_url}/${local.jupyterlite-prefix}/"
        permanent   = true
      }
    }
  }
}

resource "kubernetes_manifest" "jupyterlite-ingressroute" {
  count = var.enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.containo.us/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "jupyterlite-ingressroute"
      namespace = var.namespace
    }
    spec = {
      entryPoints = ["websecure"]
      routes = [
        {
          kind  = "Rule"
          match = "Host(`${var.external_url}`) && PathPrefix(`/${local.jupyterlite-prefix}`)"

          middlewares = concat(
            var.auth-enabled ? [
              {
                name      = var.forwardauth-middleware-name
                namespace = var.namespace
              }
            ] : [],
            [
              {
                name      = kubernetes_manifest.jupyterlite-add-slash[count.index].manifest.metadata.name
                namespace = var.namespace
              },
              {
                name      = kubernetes_manifest.jupyterlite-middleware-stripprefix[count.index].manifest.metadata.name
                namespace = var.namespace
              }
            ]
          )

          services = [
            {
              name = kubernetes_service.jupyterlite[count.index].metadata[0].name
              port = 8000
            }
          ]
        }
      ]
    }
  }
}
