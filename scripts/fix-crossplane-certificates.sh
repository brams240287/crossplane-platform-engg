#!/bin/bash
set -e

echo "🔐 Configuring Crossplane to trust corporate certificates..."
echo ""

NAMESPACE="crossplane-system"
CLUSTER_NAME="crossplane-dev"

CONTROL_PLANE_NODE="${CLUSTER_NAME}-control-plane"

echo "📦 Getting CA bundle from Kind node trust store..."
echo "  Node: ${CONTROL_PLANE_NODE}"
echo "  This bundle must include the corporate root CA (run ./scripts/fix-kind-certificates.sh first if needed)."
docker exec "${CONTROL_PLANE_NODE}" cat /etc/ssl/certs/ca-certificates.crt > /tmp/ca-certificates.crt

if [ ! -s /tmp/ca-certificates.crt ]; then
  echo "❌ Failed to retrieve CA bundle from Kind node"
  exit 1
fi

echo "✅ CA bundle retrieved ($(wc -l < /tmp/ca-certificates.crt) lines)"

# Create or update ConfigMap
if kubectl get configmap ca-bundle -n ${NAMESPACE} &> /dev/null; then
    echo "♻️  Updating existing ca-bundle ConfigMap..."
    kubectl delete configmap ca-bundle -n ${NAMESPACE}
fi

kubectl create configmap ca-bundle \
  --from-file=ca-certificates.crt=/tmp/ca-certificates.crt \
  -n ${NAMESPACE}

echo "✅ ConfigMap created"

echo "🔧 Ensuring Crossplane restarts to pick up updated CA bundle..."
echo "  Note: the Crossplane deployment mounts the ConfigMap using subPath, which requires a restart."
kubectl rollout restart deployment/crossplane -n ${NAMESPACE}

# Wait for rollout
echo "⏳ Waiting for Crossplane to restart..."
kubectl rollout status deployment/crossplane -n ${NAMESPACE} --timeout=120s

echo ""
echo "🎉 Crossplane configured to trust corporate certificates!"
echo ""
echo "📋 Next steps:"
echo "  1. Check providers: kubectl get providers"
echo "  2. Wait for providers to become healthy (may take 2-3 minutes)"
echo ""

# Clean up temp files
rm /tmp/ca-certificates.crt
