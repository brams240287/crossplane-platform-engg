#!/bin/bash
set -euo pipefail

NAME="${NAME:-azure-platform}"
ACR_NAME="${ACR_NAME:-}"
PACKAGE_REPO="${PACKAGE_REPO:-crossplane/azure-platform}"
TAG="${TAG:-v0.0.0-local}"
NAMESPACE="${NAMESPACE:-crossplane-system}"
PULL_SECRET_NAME="${PULL_SECRET_NAME:-}"

if [ -z "${ACR_NAME}" ]; then
  echo "ACR_NAME is required (e.g. myregistry)." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found on PATH." >&2
  exit 1
fi

IMAGE="${ACR_NAME}.azurecr.io/${PACKAGE_REPO}:${TAG}"

echo "📦 Installing Crossplane Configuration package: ${IMAGE}"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

if [ -n "${PULL_SECRET_NAME}" ]; then
  cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: ${NAME}
spec:
  package: ${IMAGE}
  packagePullSecrets:
    - name: ${PULL_SECRET_NAME}
EOF
else
  cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: ${NAME}
spec:
  package: ${IMAGE}
EOF
fi

echo "✅ Applied Configuration/${NAME}"

echo "⏳ Waiting for package installation (best-effort)..."
kubectl get configuration.pkg.crossplane.io "${NAME}" -o wide || true
