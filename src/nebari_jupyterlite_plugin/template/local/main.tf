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
        # Init container to clone repo and build JupyterLite content (only if content_repo is set)
        dynamic "init_container" {
          for_each = local.has_content_repo ? [1] : []
          content {
            name  = "content-builder"
            image = "ghcr.io/prefix-dev/pixi:latest"

            command = ["/bin/sh", "/scripts/build-content.sh"]
            args    = ["${var.content-repo}", "${var.content-branch}", "/output", "/build"]

            volume_mount {
              name       = "content-output"
              mount_path = "/output"
            }

            volume_mount {
              name       = "build-config"
              mount_path = "/build"
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

          # Mount built JupyterLite output if content_repo is set
          dynamic "volume_mount" {
            for_each = local.has_content_repo ? [1] : []
            content {
              name       = "content-output"
              mount_path = "/usr/share/nginx/html"
              sub_path   = "site"
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
            name = "build-config"
            config_map {
              name = kubernetes_config_map.build_config[0].metadata[0].name
            }
          }
        }

        dynamic "volume" {
          for_each = local.has_content_repo ? [1] : []
          content {
            name = "scripts"
            config_map {
              name         = kubernetes_config_map.scripts[0].metadata[0].name
              default_mode = "0755"
            }
          }
        }
      }
    }
  }
}

# ConfigMap for build script
resource "kubernetes_config_map" "scripts" {
  count = var.enabled && local.has_content_repo ? 1 : 0

  metadata {
    name      = "jupyterlite-scripts"
    namespace = var.namespace
  }

  data = {
    "build-content.sh" = file("${path.module}/scripts/build-content.sh")
  }
}

# ConfigMap for pixi build configuration
resource "kubernetes_config_map" "build_config" {
  count = var.enabled && local.has_content_repo ? 1 : 0

  metadata {
    name      = "jupyterlite-build-config"
    namespace = var.namespace
  }

  data = {
    "pixi.toml" = file("${path.module}/build-config/pixi.toml")
    "pixi.lock" = file("${path.module}/build-config/pixi.lock")
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
