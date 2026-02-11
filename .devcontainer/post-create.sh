#!/bin/bash
set -e

echo "🚀 Setting up Crossplane development environment..."

# Fix Docker socket permissions
echo "🔐 Fixing Docker socket permissions..."
sudo chmod 666 /var/run/docker.sock 2>/dev/null || echo "⚠️  Could not fix Docker socket permissions (might need manual fix)"

# Make scripts executable
echo "🔧 Setting up scripts..."
chmod +x scripts/*.sh

# Install corporate CA certificate
echo ""
echo "🔐 Installing corporate CA certificate..."
if [ -f /workspaces/*/. devcontainer/corporate-ca.crt ] || [ -f .devcontainer/corporate-ca.crt ]; then
  sudo cp .devcontainer/corporate-ca.crt /usr/local/share/ca-certificates/ 2>/dev/null || true
  sudo chmod 644 /usr/local/share/ca-certificates/corporate-ca.crt 2>/dev/null || true
  sudo update-ca-certificates 2>/dev/null || true
  echo "✅ Corporate CA certificate installed"
else
  echo "⚠️  Corporate CA certificate not found (expected at .devcontainer/corporate-ca.crt)"
fi

# Set up Git hooks (optional)
if [ -d .git ]; then
  echo "📝 Setting up Git hooks..."
  cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "🔍 Validating YAML files..."
./scripts/validate-compositions.sh
EOF
  chmod +x .git/hooks/pre-commit
fi

# Create Kind cluster automatically
echo ""
echo "🎯 Creating Kind cluster..."
if ./scripts/install-kind.sh; then
  echo "✅ Kind cluster created successfully"
  
  # Fix kubeconfig to use container IP
  echo "🔧 Fixing kubeconfig server address..."
  CLUSTER_NAME="${CLUSTER_NAME:-crossplane-dev}"
  CONTROL_PLANE_IP=$(docker inspect ${CLUSTER_NAME}-control-plane --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")
  
  if [ -n "$CONTROL_PLANE_IP" ] && [ -f ~/.kube/config ]; then
    # Fix any server address pattern (0.0.0.0, localhost, old IPs)
    sed -i "s|server: https://.*:6443|server: https://${CONTROL_PLANE_IP}:6443|g" ~/.kube/config
    sed -i "s|server: http://.*:8080|server: https://${CONTROL_PLANE_IP}:6443|g" ~/.kube/config
    echo "✅ Kubeconfig updated to use IP: ${CONTROL_PLANE_IP}"
  fi
else
  echo "⚠️  Kind cluster creation failed or skipped"
fi

# Set up Nushell with Crossplane helpers
echo ""
echo "🐚 Configuring Nushell with Crossplane helpers..."
mkdir -p ~/.config/nushell
NUSHELL_CONFIG=~/.config/nushell/config.nu

# Create basic config if it doesn't exist
if [ ! -f "$NUSHELL_CONFIG" ]; then
  echo "# Nushell Configuration" > "$NUSHELL_CONFIG"
fi

# Add Crossplane helpers source line if not already present
if ! grep -q "source /home/vscode/workspace/nu-scripts/crossplane.nu" "$NUSHELL_CONFIG"; then
  echo "" >> "$NUSHELL_CONFIG"
  echo "# Load Crossplane helpers" >> "$NUSHELL_CONFIG"
  echo "source /home/vscode/workspace/nu-scripts/crossplane.nu" >> "$NUSHELL_CONFIG"
  echo "✅ Nushell configured with Crossplane helpers"
else
  echo "✅ Nushell already configured"
fi

echo ""
echo "✅ Development environment setup complete!"
echo ""
echo "📚 All tools are pre-installed in the container:"
echo "  • kubectl (Kubernetes CLI)"
echo "  • helm (Package manager)"
echo "  • kind (Local Kubernetes)"
echo "  • crossplane CLI"
echo "  • Azure CLI (az)"
echo "  • Go 1.21"
echo "  • Python 3.11 with mkdocs"
echo "  • Node.js 20"
echo "  • Docker CLI"
echo "  • Nushell with xp commands"
echo ""
echo "📚 Next steps:"
echo "  1. Start Nushell: nu"
echo "  2. Check status: xp help"
echo "  3. Verify cluster: kubectl get nodes"
echo "  4. Install Crossplane: ./scripts/install-crossplane.sh"
echo "  5. Configure Azure: az login"
echo "  6. Install providers: ./scripts/install-providers.sh"
echo ""
