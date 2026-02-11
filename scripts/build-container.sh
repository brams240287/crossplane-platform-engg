#!/bin/bash
set -e

echo "🐋 Building Crossplane development container..."

# Build the Docker image
docker build -t crossplane-dev:latest -f .devcontainer/Dockerfile .

echo ""
echo "✅ Docker image built successfully!"
echo ""
echo "📚 Usage options:"
echo ""
echo "1️⃣  Use with VS Code Dev Containers:"
echo "   • Open VS Code"
echo "   • Command Palette (Ctrl+Shift+P)"
echo "   • 'Dev Containers: Reopen in Container'"
echo ""
echo "2️⃣  Run standalone container:"
echo "   docker run -it --rm \\"
echo "     -v \$(pwd):/home/vscode/workspace \\"
echo "     -v \$HOME/.kube:/home/vscode/.kube \\"
echo "     -v \$HOME/.azure:/home/vscode/.azure \\"
echo "     -v /var/run/docker.sock:/var/run/docker.sock \\"
echo "     --name crossplane-dev \\"
echo "     crossplane-dev:latest"
echo ""
echo "3️⃣  Push to registry (optional):"
echo "   docker tag crossplane-dev:latest <your-registry>/crossplane-dev:latest"
echo "   docker push <your-registry>/crossplane-dev:latest"
echo ""
