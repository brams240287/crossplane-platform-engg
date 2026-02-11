#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/.out"
PKG_FILE="${OUT_DIR}/azure-platform.xpkg"

ACR_NAME="${ACR_NAME:-}"
PACKAGE_REPO="${PACKAGE_REPO:-crossplane/azure-platform}"
TAG="${TAG:-v0.0.0-local}"

if [ -z "${ACR_NAME}" ]; then
  echo "ACR_NAME is required (e.g. myregistry)." >&2
  exit 1
fi

if [ ! -f "${PKG_FILE}" ]; then
  echo "Package file not found: ${PKG_FILE}" >&2
  echo "Run: ./scripts/build-platform-xpkg.sh" >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) not found on PATH." >&2
  exit 1
fi

if ! command -v crossplane >/dev/null 2>&1; then
  echo "crossplane CLI not found on PATH." >&2
  exit 1
fi

IMAGE="${ACR_NAME}.azurecr.io/${PACKAGE_REPO}:${TAG}"

echo "🔐 Logging into ACR: ${ACR_NAME}"
az acr login --name "${ACR_NAME}" >/dev/null

echo "📦 Pushing package: ${IMAGE}"
crossplane xpkg push -f "${PKG_FILE}" "${IMAGE}"

echo "✅ Pushed: ${IMAGE}"
