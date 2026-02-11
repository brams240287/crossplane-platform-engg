# Crossplane Development Container

This directory contains the Docker-based development container configuration for the Crossplane platform engineering project.

## 🎯 What's Included

The container comes pre-installed with:

### Core Tools
- **kubectl** v1.29 - Kubernetes CLI
- **helm** v3.14 - Kubernetes package manager
- **kind** v0.20 - Local Kubernetes clusters
- **Crossplane CLI** - Crossplane management
- **Azure CLI** - Azure resource management
- **Docker CLI** - Container management

### Development Tools
- **Go** v1.21.6 - For building composition functions
- **Python** v3.11 - For scripting and documentation
- **Node.js** v20 - For tooling
- **Git** - Version control
- **yq** - YAML processor
- **jq** - JSON processor
- **shellcheck** - Shell script linting
- **yamllint** - YAML validation

### Documentation Tools
- **mkdocs** - Documentation site generator
- **mkdocs-material** - Material theme
- **mkdocs-mermaid2-plugin** - Diagram support
- **pymdown-extensions** - Markdown extensions

## 🚀 Usage

### Option 1: VS Code Dev Containers (Recommended)

1. **Prerequisites:**
   - VS Code with "Dev Containers" extension installed
   - Docker Desktop running

2. **Open in Container:**
   ```bash
   # In VS Code
   # Press Ctrl+Shift+P (Cmd+Shift+P on Mac)
   # Select: "Dev Containers: Reopen in Container"
   ```

3. **Wait for container to build** (first time ~5-10 minutes)

4. **Start developing!** All tools are ready to use.

### Option 2: Build and Run Manually

1. **Build the container:**
   ```bash
   ./scripts/build-container.sh
   # OR manually:
   docker build -t crossplane-dev:latest -f .devcontainer/Dockerfile .
   ```

2. **Run the container:**
   ```bash
   docker run -it --rm \
     -v $(pwd):/home/vscode/workspace \
     -v $HOME/.kube:/home/vscode/.kube \
     -v $HOME/.azure:/home/vscode/.azure \
     -v /var/run/docker.sock:/var/run/docker.sock \
     --name crossplane-dev \
     crossplane-dev:latest
   ```

3. **Inside the container:**
   ```bash
   cd /home/vscode/workspace
   ./scripts/install-kind.sh
   ./scripts/install-crossplane.sh
   ```

### Option 3: Push to Registry (Team Sharing)

1. **Build and tag:**
   ```bash
   docker build -t crossplane-dev:latest -f .devcontainer/Dockerfile .
   docker tag crossplane-dev:latest <your-registry>.azurecr.io/crossplane-dev:latest
   ```

2. **Push to Azure Container Registry:**
   ```bash
   az acr login --name <your-registry>
   docker push <your-registry>.azurecr.io/crossplane-dev:latest
   ```

3. **Update devcontainer.json** to use the remote image:
   ```json
   {
     "image": "<your-registry>.azurecr.io/crossplane-dev:latest"
   }
   ```

## 📂 File Structure

```
.devcontainer/
├── Dockerfile           # Container definition
├── devcontainer.json    # VS Code configuration
├── post-create.sh       # Post-creation setup script
└── README.md           # This file
```

## 🔧 Configuration

### devcontainer.json Features

- **Docker-in-Docker**: Build and run containers from inside the dev container
- **Volume Mounts**: 
  - `~/.kube` - Access your Kubernetes configs
  - `~/.azure` - Access your Azure credentials
  - Workspace files are automatically mounted
- **VS Code Extensions**: Pre-configured with Kubernetes, Azure, YAML, and Go extensions
- **Environment Variables**: 
  - `CROSSPLANE_NAMESPACE=crossplane-system`
  - `KUBECONFIG=/home/vscode/.kube/config`

### Dockerfile Highlights

- Based on Ubuntu 22.04
- User: `vscode` (non-root with sudo)
- Python packages installed in user space
- All tools installed system-wide
- Bash completion configured
- Go tools for Crossplane functions

## 🛠️ Post-Creation Setup

After the container starts, `post-create.sh` automatically:
1. Makes all scripts executable
2. Sets up Git pre-commit hooks for YAML validation
3. Displays helpful next steps

## 📝 Development Workflow

1. **Start Container** (via VS Code or manually)
2. **Configure Azure:**
   ```bash
   az login
   az account set --subscription <your-subscription-id>
   ```
3. **Create Local Cluster:**
   ```bash
   ./scripts/install-kind.sh
   ```
4. **Install Crossplane:**
   ```bash
   ./scripts/install-crossplane.sh
   ./scripts/install-providers.sh
   ```
5. **Develop & Test:**
   ```bash
   kubectl apply -f manifests/
   kubectl apply -f claims/dev/
   ```
6. **Documentation:**
   ```bash
   mkdocs serve
   # Visit http://localhost:8001/docs
   ```

## 🔒 Security Best Practices

### What's Mounted
- ✅ **~/.kube** - Read-only access to cluster configs
- ✅ **~/.azure** - Azure credentials for authentication
- ✅ **Workspace** - Your code and manifests

### What's NOT in the Image
- ❌ No hardcoded credentials
- ❌ No sensitive data
- ❌ No production secrets

### Recommendations
- Use Azure Managed Identity in production
- Never commit `.env` files with secrets
- Use Azure Key Vault for production credentials
- Rotate service principal secrets regularly

## 🐛 Troubleshooting

### Container won't build
```bash
# Check Docker is running
docker ps

# Clean build (no cache)
docker build --no-cache -t crossplane-dev:latest -f .devcontainer/Dockerfile .
```

### Can't connect to Kubernetes
```bash
# Verify kubeconfig is mounted
ls -la ~/.kube/config

# Test kubectl
kubectl cluster-info

# Check KUBECONFIG environment variable
echo $KUBECONFIG
```

### Python packages missing
```bash
# Reinstall in container
pip3 install --user mkdocs mkdocs-material mkdocs-mermaid2-plugin
```

### Docker-in-Docker not working
```bash
# Verify docker socket is mounted
ls -la /var/run/docker.sock

# Test docker
docker ps
```

## 🚀 Advanced Usage

### Custom Environment Variables

Add to `devcontainer.json`:
```json
"containerEnv": {
  "AZURE_SUBSCRIPTION_ID": "${localEnv:AZURE_SUBSCRIPTION_ID}",
  "MY_CUSTOM_VAR": "value"
}
```

### Additional Tools

Add to `Dockerfile`:
```dockerfile
RUN apt-get update && apt-get install -y \
    my-custom-tool \
    && rm -rf /var/lib/apt/lists/*
```

### VS Code Settings

Customize in `devcontainer.json` → `customizations.vscode.settings`:
```json
"[yaml]": {
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "redhat.vscode-yaml"
}
```

## 📚 References

- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
- [Docker Documentation](https://docs.docker.com/)
- [Crossplane Docs](https://docs.crossplane.io/)
- [Azure CLI Reference](https://learn.microsoft.com/en-us/cli/azure/)

---

**Built with ❤️ for consistent, reproducible development environments**
