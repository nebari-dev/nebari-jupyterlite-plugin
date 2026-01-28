# nebari-jupyterlite-plugin

[![CI](https://github.com/nebari-dev/nebari-jupyterlite-plugin/actions/workflows/ci.yml/badge.svg)](https://github.com/nebari-dev/nebari-jupyterlite-plugin/actions/workflows/ci.yml)
[![Docker](https://github.com/nebari-dev/nebari-jupyterlite-plugin/actions/workflows/docker.yml/badge.svg)](https://github.com/nebari-dev/nebari-jupyterlite-plugin/actions/workflows/docker.yml)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

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
| `content_repo` | string | `""` | Git repository URL for custom notebooks/files |
| `content_branch` | string | `"main"` | Git branch to use for content repository |
| `overrides` | dict | `{}` | Override Kubernetes resource settings |

### Custom Content

Load notebooks and files from a git repository:

```yaml
jupyterlite:
  enabled: true
  content_repo: "https://github.com/your-org/notebooks"
  content_branch: "main"
```

The content repository is cloned at pod startup and built into JupyterLite using `jupyter lite build`. Files will appear in the JupyterLite file browser.

### Installing Packages

JupyterLite uses [Pyodide](https://pyodide.org/) to run Python in the browser. Packages can be installed in two ways:

1. **Pyodide packages** (numpy, pandas, sympy, xarray, etc.) - Available immediately, just `import` them
2. **Other PyPI packages** - Install at runtime with `%pip install <package>`

```python
# Pyodide packages - just import
import numpy as np
import pandas as pd

# Other packages - install first
%pip install pyfiglet
import pyfiglet
```

See the [list of packages in Pyodide](https://pyodide.org/en/stable/usage/packages-in-pyodide.html) and the [JupyterLite packages documentation](https://jupyterlite.readthedocs.io/en/latest/howto/pyodide/packages.html) for more details.

### Overrides

You can customize the deployment using the `overrides` option:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `image` | string | `quay.io/nebari/nebari-jupyterlite-plugin:latest` | Docker image to use |
| `resources.cpu_request` | string | `"100m"` | CPU request |
| `resources.memory_request` | string | `"128Mi"` | Memory request |
| `resources.cpu_limit` | string | `"500m"` | CPU limit |
| `resources.memory_limit` | string | `"256Mi"` | Memory limit |

Example:

```yaml
jupyterlite:
  enabled: true
  overrides:
    image: "quay.io/nebari/nebari-jupyterlite-plugin:v0.1.0"
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
1. Deploys JupyterLite as a Kubernetes Deployment using `quay.io/nebari/nebari-jupyterlite-plugin`
2. Creates a ClusterIP Service to expose the deployment
3. Configures Traefik IngressRoute to route `/jupyterlite/` traffic
4. Optionally integrates with Nebari's forward authentication
5. If `content_repo` is set, an init container clones the repo and builds JupyterLite with the content

## Requirements

- Nebari >= 2025.1.1
- Kubernetes cluster with Traefik ingress controller

## License

Apache-2.0
