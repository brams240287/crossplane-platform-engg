#!/bin/bash
set -e

echo "🚀 Installing Kind (Kubernetes in Docker)..."

# Configuration
KIND_VERSION="${KIND_VERSION:-v0.20.0}"
CLUSTER_NAME="${CLUSTER_NAME:-crossplane-dev}"
K8S_VERSION="${K8S_VERSION:-v1.32.0}"

# Function to check if kind is installed
check_kind_installed() {
    if command -v kind &> /dev/null; then
        echo "✅ Kind is already installed: $(kind version)"
        return 0
    else
        return 1
    fi
}

# Function to install kind
install_kind() {
    echo "📦 Installing Kind ${KIND_VERSION}..."
    
    # Detect OS and architecture
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    # Map architecture names
    case ${ARCH} in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
    esac
    
    # Download and install kind
    curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${OS}-${ARCH}"
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    echo "✅ Kind ${KIND_VERSION} installed successfully"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info &> /dev/null; then
        echo "❌ Error: Docker is not running or not installed"
        echo "Please start Docker and try again"
        exit 1
    fi
    echo "✅ Docker is running"
}

# Function to create kind cluster
create_cluster() {
    echo "📦 Creating Kind cluster: ${CLUSTER_NAME}..."
    
    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
        echo "⚠️  Cluster ${CLUSTER_NAME} already exists"
        read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🗑️  Deleting existing cluster..."
            kind delete cluster --name ${CLUSTER_NAME}
        else
            echo "✅ Using existing cluster"
            kind get kubeconfig --name ${CLUSTER_NAME} > ~/.kube/config
            return 0
        fi
    fi
    
    # Create cluster configuration
    cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF
    
    # Create the cluster
    kind create cluster \
        --config /tmp/kind-config.yaml \
        --image kindest/node:${K8S_VERSION} \
        --wait 120s
    
    # Clean up temp config
    rm /tmp/kind-config.yaml
    
    echo "✅ Cluster ${CLUSTER_NAME} created successfully"
}

# Function to verify cluster
verify_cluster() {
    echo "🔍 Verifying cluster..."
    
    # Wait for nodes to be ready
    echo "⏳ Waiting for nodes to be ready..."
    kubectl wait --for=condition=Ready nodes --all --timeout=300s
    
    # Display cluster info
    echo ""
    echo "📊 Cluster Information:"
    echo "======================="
    kubectl cluster-info
    echo ""
    echo "📋 Nodes:"
    kubectl get nodes -o wide
    echo ""
    echo "📦 System Pods:"
    kubectl get pods -A
    echo ""
}

# Function to copy kubeconfig locally
copy_kubeconfig() {
    local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
    local LOCAL_KUBECONFIG="${PROJECT_DIR}/.kubeconfig"
    
    echo "📋 Copying kubeconfig to project directory..."
    
    # Copy the kubeconfig
    cp ~/.kube/config "${LOCAL_KUBECONFIG}"
    
    # Fix apiVersion if needed (ensure it's v1)
    sed -i 's/^apiVersion: v0$/apiVersion: v1/' "${LOCAL_KUBECONFIG}"
    
    echo "✅ Kubeconfig copied to: ${LOCAL_KUBECONFIG}"
    echo ""
    echo "💡 To use this config:"
    echo "  export KUBECONFIG=${LOCAL_KUBECONFIG}"
    echo "  or"
    echo "  kubectl --kubeconfig=${LOCAL_KUBECONFIG} get nodes"
    echo ""
}

# Main execution
main() {
    echo "🎯 Kind Cluster Setup"
    echo "===================="
    echo "Cluster Name: ${CLUSTER_NAME}"
    echo "Kubernetes Version: ${K8S_VERSION}"
    echo ""
    
    # Check prerequisites
    check_docker
    
    # Install kind if not present
    if ! check_kind_installed; then
        install_kind
    fi
    
    # Create cluster
    create_cluster
    
    # Verify cluster
    verify_cluster
    
    # Copy kubeconfig to project directory
    copy_kubeconfig
    
    echo ""
    echo "🎉 Kind cluster setup complete!"
    echo ""
    echo "📝 Next steps:"
    echo "  1. Install Crossplane: ./scripts/install-crossplane.sh"
    echo "  2. Install Azure providers: ./scripts/install-providers.sh"
    echo "  3. Configure Azure credentials (see GETTING-STARTED.md)"
    echo ""
    echo "💡 Useful commands:"
    echo "  • List clusters: kind get clusters"
    echo "  • Delete cluster: kind delete cluster --name ${CLUSTER_NAME}"
    echo "  • Get kubeconfig: kind get kubeconfig --name ${CLUSTER_NAME}"
    echo ""
}

# Run main function
main
