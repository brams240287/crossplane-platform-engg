#!/bin/bash
set -e

echo "🚀 Installing Crossplane..."

# Configuration
NAMESPACE="${NAMESPACE:-crossplane-system}"

# Create namespace if it doesn't exist
echo "📦 Creating namespace ${NAMESPACE}..."
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Crossplane Helm repository
echo "📦 Adding Crossplane Helm repository..."
helm repo add crossplane-stable https://charts.crossplane.io/stable || echo "Repository already exists"
helm repo update crossplane-stable 2>/dev/null || helm repo update 

# Check if Crossplane is already installed
if helm list -n ${NAMESPACE} | grep -q crossplane; then
    echo "⚠️  Crossplane is already installed"
    echo "📋 Current status:"
    helm list -n ${NAMESPACE}
    kubectl get pods -n ${NAMESPACE}
    echo ""
    read -p "Do you want to upgrade it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "📦 Upgrading Crossplane..."
        helm upgrade crossplane \
          crossplane-stable/crossplane \
          --namespace ${NAMESPACE} \
          --wait
    else
        echo "✅ Using existing Crossplane installation"
        exit 0
    fi
else
    # Install Crossplane (latest version)
    echo "📦 Installing Crossplane..."
    
    helm install crossplane \
      crossplane-stable/crossplane \
      --namespace ${NAMESPACE} \
      --create-namespace \
      --wait
fi

# Verify installation
echo "✅ Verifying Crossplane installation..."
kubectl wait --for=condition=Available deployment/crossplane \
  -n ${NAMESPACE} \
  --timeout=900s

# Install Crossplane CLI
echo "📦 Installing Crossplane CLI..."
if ! command -v crossplane &> /dev/null; then
    curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
    sudo mv crossplane /usr/local/bin/
    echo "✅ Crossplane CLI installed"
else
    echo "✅ Crossplane CLI already installed"
fi

# Display version
echo ""
echo "🎉 Crossplane installation complete!"
echo ""
kubectl get pods -n ${NAMESPACE}
echo ""
crossplane --version
