# nebari-jupyterlite-plugin

A Nebari plugin that deploys [JupyterLite](https://jupyterlite.readthedocs.io/) - a lightweight Jupyter environment that runs entirely in the browser.

## Installation

```bash
pip install nebari-jupyterlite-plugin
```

Or for development:

```bash
pip install -e /path/to/nebari-jupyterlite-plugin
```

## Configuration

Add the following to your `nebari-config.yaml`:

```yaml
jupyterlite:
  enabled: true
  auth_enabled: true  # Set to false for public access
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `true` | Whether to deploy JupyterLite |
| `auth_enabled` | bool | `true` | Whether to require Nebari authentication |
| `overrides` | dict | `{}` | Override Kubernetes resource settings |

### Overrides

You can customize the deployment using the `overrides` option:

```yaml
jupyterlite:
  enabled: true
  overrides:
    image: "jupyterlite/demo:0.1.0"  # Use specific version
    replicas: 2                       # Multiple replicas for HA
    resources:
      cpu_request: "200m"
      memory_request: "256Mi"
      cpu_limit: "1000m"
      memory_limit: "512Mi"
```

## Usage

After deploying Nebari with this plugin:

1. Run `nebari deploy`
2. Access JupyterLite at `https://<nebari-domain>/jupyterlite/`

## Features

- **Browser-based**: JupyterLite runs entirely in the browser with no server-side computation
- **Optional Authentication**: Can be protected by Nebari's authentication or made public
- **Lightweight**: Minimal resource requirements as it serves static files
- **Quick Access**: Ideal for demos, tutorials, or quick experiments

## How It Works

This plugin:
1. Deploys the official `jupyterlite/demo` Docker image as a Kubernetes Deployment
2. Creates a ClusterIP Service to expose the deployment
3. Configures Traefik IngressRoute to route `/jupyterlite/` traffic
4. Optionally integrates with Nebari's forward authentication

## Requirements

- Nebari >= 2025.1.1
- Kubernetes cluster with Traefik ingress controller

## License

Apache-2.0
