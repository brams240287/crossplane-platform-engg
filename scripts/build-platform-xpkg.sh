#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/.out"
TOOLS_DIR="${OUT_DIR}/tools"
BUILD_DIR="${OUT_DIR}/platform-package"
PKG_FILE="${OUT_DIR}/azure-platform.xpkg"

# Crossplane v2 cluster can be managed with older CLIs, but packaging v2 APIs
# (e.g. apiextensions.crossplane.io/v2 XRDs) requires a v2 CLI.
CROSSPLANE_CLI_VERSION="${CROSSPLANE_CLI_VERSION:-v2.1.4}"

# If your network cannot resolve releases.crossplane.io (common behind corporate DNS/proxy),
# set this to an internal mirror URL that hosts the crank binary.
# Example:
#   export CROSSPLANE_CLI_BASE_URL="https://my-artifacts.example.com/crossplane"
# Expected layout:
#   ${CROSSPLANE_CLI_BASE_URL}/${CROSSPLANE_CLI_VERSION}/bin/linux_amd64/crank
CROSSPLANE_CLI_BASE_URL="${CROSSPLANE_CLI_BASE_URL:-https://releases.crossplane.io/stable}"

mkdir -p "${OUT_DIR}" "${TOOLS_DIR}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

ensure_crossplane_cli() {
  local have_cli=""
  if command -v crossplane >/dev/null 2>&1; then
    # Example: Client Version: v2.1.4
    if crossplane version 2>/dev/null | grep -qE '^Client Version: v2\.'; then
      have_cli="yes"
    fi
  fi

  if [ -n "$have_cli" ]; then
    return 0
  fi

  echo "⬇️  Installing Crossplane CLI (crank) ${CROSSPLANE_CLI_VERSION} into ${TOOLS_DIR}"
  if ! curl -fsSL "${CROSSPLANE_CLI_BASE_URL}/${CROSSPLANE_CLI_VERSION}/bin/linux_amd64/crank" -o "${TOOLS_DIR}/crossplane"; then
    echo "❌ Failed to download Crossplane CLI from: ${CROSSPLANE_CLI_BASE_URL}" >&2
    echo "   If you see 'Could not resolve host', configure DNS/proxy for Docker/devcontainer" >&2
    echo "   or set CROSSPLANE_CLI_BASE_URL to an internal mirror." >&2
    exit 1
  fi
  chmod +x "${TOOLS_DIR}/crossplane"
  export PATH="${TOOLS_DIR}:${PATH}"
}

ensure_crossplane_cli

if [ ! -f "${ROOT_DIR}/packages/platform/crossplane.yaml" ]; then
  echo "Missing packages/platform/crossplane.yaml" >&2
  exit 1
fi

# Assemble package from source-of-truth manifests.
# IMPORTANT: `crossplane xpkg build` for Configuration packages supports ONLY:
# - Composition
# - CompositeResourceDefinition
# Any other YAML (Providers, Functions, RBAC, etc.) must be excluded.
cp "${ROOT_DIR}/packages/platform/crossplane.yaml" "${BUILD_DIR}/crossplane.yaml"
mkdir -p "${BUILD_DIR}/manifests"

if [ -d "${ROOT_DIR}/manifests/compositions" ]; then
  cp -R "${ROOT_DIR}/manifests/compositions" "${BUILD_DIR}/manifests/"
fi

# Build the package
crossplane xpkg build --package-root "${BUILD_DIR}" --package-file "${PKG_FILE}"

echo "✅ Built Crossplane Configuration package: ${PKG_FILE}"
