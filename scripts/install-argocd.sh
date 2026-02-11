#!/bin/bash
# Install and configure ArgoCD for Crossplane GitOps

set -euo pipefail

echo "🚀 Installing ArgoCD..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"

# Install / upgrade ArgoCD (idempotent)
# If ArgoCD is already installed, skip unless forced.
if kubectl get deployment argocd-server -n argocd >/dev/null 2>&1; then
	if [[ "${FORCE_ARGOCD_INSTALL:-0}" == "1" ]]; then
		echo "♻️  ArgoCD already installed; FORCE_ARGOCD_INSTALL=1 so re-applying manifest..."
		kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_MANIFEST_URL"
	else
		echo "✅ ArgoCD already installed; skipping install (set FORCE_ARGOCD_INSTALL=1 to force)."
	fi
else
	kubectl apply -n argocd --server-side --force-conflicts -f "$ARGOCD_MANIFEST_URL"
fi

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

echo "✅ ArgoCD installed successfully"

# Get initial password
echo ""
echo "📝 ArgoCD Initial Admin Password:"
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
	kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
else
	echo "(initial admin secret not found yet)"
fi
echo ""
echo ""

echo "🔧 Applying ArgoCD Applications for Crossplane..."

# Apply only known-good manifests so the install doesn't fail if the directory
# contains experimental files.
kubectl apply -f config/argocd-applications/crossplane-providers.yaml

if [[ -f config/argocd-applications/crossplane-platform-appset.yaml ]]; then
	kubectl apply -f config/argocd-applications/crossplane-platform-appset.yaml
fi

if [[ -f config/argocd-applications/crossplane-claims-appset.yaml ]]; then
	kubectl apply -f config/argocd-applications/crossplane-claims-appset.yaml
fi

echo ""
echo "📋 ArgoCD objects:"
kubectl get applicationsets -n argocd 2>/dev/null || true
kubectl get applications -n argocd 2>/dev/null || true

echo ""
echo "✅ ArgoCD configured for GitOps!"
echo ""
echo "📍 Access ArgoCD UI:"
echo "   1. Run: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   2. Open: https://localhost:8080"
echo "   3. Login with:"
echo "      Username: admin"
echo "      Password: (shown above)"
echo ""
echo "🔄 GitOps configured:"
echo "   - crossplane-providers (Application)"
echo "   - crossplane-platform-* (ApplicationSets)"
echo "   - crossplane-claims-* (ApplicationSets)"
