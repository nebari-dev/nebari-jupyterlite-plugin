#!/bin/sh
# Init container script for building JupyterLite with content from a git repo
# Used by: Kubernetes init container, CI integration tests
set -e

CONTENT_REPO="${1:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
CONTENT_BRANCH="${2:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
OUTPUT_DIR="${3:?Usage: $0 <repo_url> <branch> <output_dir> <config_dir>}"
CONFIG_DIR="${4:-/build}"

apt-get update && apt-get install -y --no-install-recommends git ca-certificates

echo "Cloning ${CONTENT_REPO} (branch: ${CONTENT_BRANCH})..."
git clone --depth 1 --branch "${CONTENT_BRANCH}" "${CONTENT_REPO}" /tmp/content

# Copy config to writable directory (ConfigMap is read-only)
echo "Setting up build environment..."
mkdir -p /tmp/build
cp "${CONFIG_DIR}/pixi.toml" "${CONFIG_DIR}/pixi.lock" /tmp/build/

echo "Installing dependencies from lock file..."
cd /tmp/build && pixi install --frozen

echo "Building JupyterLite with content..."
pixi run jupyter lite build --contents /tmp/content --output-dir "${OUTPUT_DIR}/site"

echo "Content built successfully."
