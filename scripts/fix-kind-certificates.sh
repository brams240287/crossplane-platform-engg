#!/bin/bash
set -e

echo "🔐 Fixing Kind cluster certificates for corporate firewall..."

CLUSTER_NAME="${CLUSTER_NAME:-crossplane-dev}"

# Get the corporate CA certificate chain from the intercepted connection.
# NOTE: In TLS interception setups (e.g., Zscaler), the chain presented for xpkg.upbound.io
# is typically signed by a corporate root/intermediate that is not in the default trust store.
echo "📥 Extracting corporate CA certificate chain (via xpkg.upbound.io)..."
docker exec "${CLUSTER_NAME}-control-plane" bash -c "openssl s_client -connect xpkg.upbound.io:443 -showcerts </dev/null 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'" > /tmp/corporate-ca.crt

if [ ! -s /tmp/corporate-ca.crt ]; then
    echo "❌ Failed to extract certificate"
    exit 1
fi

echo "✅ Certificate extracted"

# Function to add certificate to a node
add_cert_to_node() {
    local NODE=$1
    echo "📝 Adding certificate to node: ${NODE}"
    
    # Copy certificate to node
    docker cp /tmp/corporate-ca.crt "${NODE}":/usr/local/share/ca-certificates/corporate-ca.crt
    
    # Update certificates
    docker exec "${NODE}" bash -c "update-ca-certificates"
    
    # Restart containerd to pick up new certs
    docker exec "${NODE}" bash -c "systemctl restart containerd || killall containerd"
    
    echo "✅ Certificate added to ${NODE}"
}

# Get all nodes in the cluster
NODES=$(kind get nodes --name "${CLUSTER_NAME}")

# Add certificate to each node
for NODE in $NODES; do
    add_cert_to_node "$NODE"
done

# Clean up
rm /tmp/corporate-ca.crt

echo ""
echo "🎉 Certificate fix complete!"
echo ""
echo "📋 Next steps:"
echo "  1. Wait 30 seconds for containerd to restart"
echo "  2. Run: ./scripts/install-crossplane.sh"
echo ""
