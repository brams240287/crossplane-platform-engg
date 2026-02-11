#!/bin/bash
set -e

echo "🚀 Installing Crossplane Providers..."

# Apply provider manifests
echo "📦 Installing Azure providers..."
kubectl apply -f manifests/providers/

# Wait for providers to be installed
echo "⏳ Waiting for providers to be healthy..."
sleep 10

# Check provider status
echo "📊 Provider status:"
kubectl get providers.pkg.crossplane.io

# Wait for all providers to be healthy
echo "⏳ Waiting for all providers to become healthy (this may take a few minutes)..."
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io --all --timeout=600s

echo ""
echo "✅ All providers installed successfully!"
echo ""
kubectl get providers.pkg.crossplane.io
