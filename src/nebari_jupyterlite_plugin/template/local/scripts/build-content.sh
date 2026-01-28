#!/bin/sh
# Init container script for building JupyterLite with content from a git repo
# Used by: Kubernetes init container, CI integration tests
set -e

CONTENT_REPO="${1:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
CONTENT_BRANCH="${2:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
OUTPUT_DIR="${3:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
CONFIG_DIR="${4:-/build}"

apt update && apt install -y --no-install-recommends git ca-certificates jq

echo "Cloning ${CONTENT_REPO} (branch: ${CONTENT_BRANCH})..."
git clone --depth 1 --branch "${CONTENT_BRANCH}" "${CONTENT_REPO}" /tmp/content

# Create requirements.txt from JUPYTERLITE_PACKAGES env var if set
if [ -n "${JUPYTERLITE_PACKAGES}" ] && [ "${JUPYTERLITE_PACKAGES}" != "[]" ]; then
    echo "Creating requirements.txt from packages config..."
    echo "${JUPYTERLITE_PACKAGES}" | jq -r '.[]' > /tmp/content/requirements.txt
    cat /tmp/content/requirements.txt
fi

# Copy config to writable directory (ConfigMap is read-only)
echo "Setting up build environment..."
mkdir -p /tmp/build
cp "${CONFIG_DIR}/pixi.toml" "${CONFIG_DIR}/pixi.lock" /tmp/build/

echo "Installing dependencies from lock file..."
cd /tmp/build && pixi install --frozen

echo "Building JupyterLite with content..."
# Kubernetes automatically creates env vars for services: JUPYTERLITE_PORT=tcp://IP:PORT
# But jupyterlite-core reads JUPYTERLITE_PORT expecting an integer port number
# This causes: ValueError: invalid literal for int() with base 10: 'tcp://...'
# Fix: unset the conflicting env var before building
unset JUPYTERLITE_PORT
pixi run jupyter lite build --contents /tmp/content --output-dir "${OUTPUT_DIR}/site"

echo "Content built successfully."
