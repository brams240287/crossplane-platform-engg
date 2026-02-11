#!/bin/bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-crossplane-system}"
ACR_NAME="${ACR_NAME:-}"
SECRET_NAME="${SECRET_NAME:-acr-pull}"

if [ -z "${ACR_NAME}" ]; then
  echo "ACR_NAME is required (e.g. myregistry)." >&2
  exit 1
fi

if ! command -v az >/dev/null 2>&1; then
  echo "Azure CLI (az) not found on PATH." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not found on PATH." >&2
  exit 1
fi

# Use ACR access token as the docker-registry password.
# Username is a fixed GUID for ACR token auth.
USERNAME="00000000-0000-0000-0000-000000000000"
TOKEN="$(az acr login --name "${ACR_NAME}" --expose-token --output tsv --query accessToken)"

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --docker-server "${ACR_NAME}.azurecr.io" \
  --docker-username "${USERNAME}" \
  --docker-password "${TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Created/updated imagePullSecret ${NAMESPACE}/${SECRET_NAME} for ${ACR_NAME}.azurecr.io"
