variable "enabled" {
  type        = bool
  description = "Whether to deploy JupyterLite"
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace to deploy JupyterLite"
}

variable "external_url" {
  type        = string
  description = "External URL for the Nebari deployment"
}

variable "auth-enabled" {
  type        = bool
  description = "Whether to enable authentication via forward auth"
  default     = true
}

variable "forwardauth-middleware-name" {
  type        = string
  description = "Name of the forward auth middleware"
  default     = ""
}

variable "content-repo" {
  type        = string
  description = "Git repository URL for JupyterLite content (notebooks, files)"
  default     = ""
}

variable "content-branch" {
  type        = string
  description = "Git branch for content repository"
  default     = "main"
}

variable "overrides" {
  type        = string
  default     = "{}"
  description = "JSON-encoded overrides for Kubernetes resources"
}
