# Getting Started with Crossplane (Greenfield)

## 🎯 Overview

This guide walks you through setting up Crossplane from scratch for Azure infrastructure provisioning. Since this is a **greenfield deployment**, there's no need to import existing resources.

## 🛠️ Prerequisites

### Required
- **Kubernetes cluster** (v1.28+): AKS, kind, minikube, or k3s
- **Azure subscription** with Contributor access
- **Azure Service Principal** or Managed Identity
- **kubectl** configured for your cluster

### Development Environment Options

#### Option 1: Devbox (Local - Recommended for nushell users)
```bash
# Install devbox
curl -fsSL https://get.jetpack.io/devbox | bash

# Enter devbox shell (loads all tools)
devbox shell

# Run setup
devbox run setup
```

#### Option 2: Devcontainer (Consistent across team)
```bash
# Open in VS Code
code .

# Command Palette (Ctrl+Shift+P):
# "Dev Containers: Reopen in Container"
```

**Why use devcontainer?**
- ✅ Identical environment for all developers
- ✅ No "works on my machine" issues
- ✅ Safe for pushing to OCI registries (consistent builds)
- ✅ Pre-configured with all tools and VS Code extensions
- ✅ Isolated from your local system

## 📋 Step-by-Step Setup

### Step 1: Verify Environment

```bash
# Check tools are available
kubectl version --client
helm version
crossplane --version
az version

# Check cluster access
kubectl cluster-info
kubectl get nodes
```

### Step 2: Set Up Azure Credentials

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription <your-subscription-id>

# Create Service Principal for Crossplane
az ad sp create-for-rbac \
  --name crossplane-azure-provider \
  --role Contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --query "{clientId: appId, clientSecret: password, tenantId: tenant}"

# Save the output - you'll need it!
```

### Step 3: Create Azure Credentials Secret

**Option A: Using .env file (Recommended)**

```bash
# Create crossplane-system namespace
kubectl create namespace crossplane-control

# Create .env file with your credentials
cat > .env <<EOF
AZURE_CLIENT_ID=<your-client-id>
AZURE_CLIENT_SECRET=<your-client-secret>
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
AZURE_TENANT_ID=<your-tenant-id>
EOF

# Generate JSON from .env and create secret
source .env
cat > azure-credentials.json <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "tenantId": "${AZURE_TENANT_ID}"
}
EOF

# Create Kubernetes secret
kubectl create secret generic azure-secret \
  --from-file=creds=./azure-credentials.json \
  --namespace crossplane-system

# Clean up (keep .env, delete JSON)
rm azure-credentials.json
```

**Option B: Direct JSON creation**

```bash
# Create Azure credentials JSON directly
cat > azure-credentials.json <<EOF
{
  "clientId": "<your-client-id>",
  "clientSecret": "<your-client-secret>",
  "subscriptionId": "<your-subscription-id>",
  "tenantId": "<your-tenant-id>"
}
EOF

# Create Kubernetes secret

kubectl create secret generic azure-secret \
  --from-file=creds=./azure-credentials.json \
  --namespace crossplane-system

# Delete the file (don't commit it!)
rm azure-credentials.json
```

**Note:** `.env` is already in `.gitignore` so it's safe to keep locally.

### Step 4: Install Crossplane

```bash
./scripts/install-crossplane.sh

# Verify installation
kubectl get pods -n crossplane-system
kubectl get crds | grep crossplane
```

### Step 5: Install Azure Providers

First, create the provider manifests:

```bash
mkdir -p manifests/providers
```

Create `manifests/providers/provider-azure-network.yaml`:
```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.42.0
  packagePullPolicy: IfNotPresent
```

Create similar files for other providers:
- `provider-azure-compute.yaml`
- `provider-azure-storage.yaml`
- `provider-azure-containerservice.yaml`

Then install:
```bash
./scripts/install-providers.sh

# Check provider status
kubectl get providers
# Wait for all providers to be HEALTHY and INSTALLED=True
```

### Step 6: Configure Provider Authentication

Create `manifests/provider-configs/azure-provider-config.yaml`:
```yaml
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-secret
      key: creds
```

Apply it:
```bash
kubectl apply -f manifests/provider-configs/azure-provider-config.yaml

# Verify
kubectl get providerconfigs
```

### Step 7: Create Your First Composition

Let's start with a simple virtual network composition.

Create `manifests/compositions/network/xrd-virtualnetwork.yaml`:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xvirtualnetworks.azure.platform.io
spec:
  group: azure.platform.io
  names:
    kind: XVirtualNetwork
    plural: xvirtualnetworks
  claimNames:
    kind: VirtualNetwork
    plural: virtualnetworks
  versions:
  - name: v1alpha1
    served: true
    referenceable: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              parameters:
                type: object
                properties:
                  location:
                    type: string
                    default: "eastus"
                  addressSpace:
                    type: string
                    default: "10.0.0.0/16"
                  subnetAddressPrefix:
                    type: string
                    default: "10.0.1.0/24"
                required:
                - location
            required:
            - parameters
```

Create `manifests/compositions/network/composition-virtualnetwork.yaml`:
```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: virtualnetwork-azure
  labels:
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: azure.platform.io/v1alpha1
    kind: XVirtualNetwork
  
  mode: Pipeline
  pipeline:
  - step: patch-and-transform
    functionRef:
      name: function-patch-and-transform
    input:
      apiVersion: pt.fn.crossplane.io/v1beta1
      kind: Resources
      resources:
      - name: resourceGroup
        base:
          apiVersion: azure.upbound.io/v1beta1
          kind: ResourceGroup
          spec:
            forProvider:
              location: eastus
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
      
      - name: virtualNetwork
        base:
          apiVersion: network.azure.upbound.io/v1beta1
          kind: VirtualNetwork
          spec:
            forProvider:
              addressSpace:
              - "10.0.0.0/16"
              location: eastus
              resourceGroupNameSelector:
                matchControllerRef: true
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.location
          toFieldPath: spec.forProvider.location
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.addressSpace
          toFieldPath: spec.forProvider.addressSpace[0]
      
      - name: subnet
        base:
          apiVersion: network.azure.upbound.io/v1beta1
          kind: Subnet
          spec:
            forProvider:
              addressPrefixes:
              - "10.0.1.0/24"
              resourceGroupNameSelector:
                matchControllerRef: true
              virtualNetworkNameSelector:
                matchControllerRef: true
        patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.subnetAddressPrefix
          toFieldPath: spec.forProvider.addressPrefixes[0]
```

Apply the composition:
```bash
kubectl apply -f manifests/compositions/network/

# Verify
kubectl get xrd
kubectl get compositions
```

### Step 8: Create Your First Claim

Create `claims/dev/my-first-vnet.yaml`:
```yaml
apiVersion: azure.platform.io/v1alpha1
kind: VirtualNetwork
metadata:
  name: dev-vnet-001
  namespace: default
spec:
  parameters:
    location: eastus
    addressSpace: "10.10.0.0/16"
    subnetAddressPrefix: "10.10.1.0/24"
  compositionSelector:
    matchLabels:
      provider: azure
```

Apply and watch:
```bash
kubectl apply -f claims/dev/my-first-vnet.yaml

# Watch resources being created
kubectl get virtualnetwork
kubectl describe virtualnetwork dev-vnet-001

# Check Azure resources
kubectl get managed
az network vnet list -o table
```

## 🎉 Success Criteria

After completing these steps:
- ✅ Crossplane is running in your cluster
- ✅ Azure providers are installed and healthy
- ✅ Your first composition is created
- ✅ Your first claim provisioned Azure resources
- ✅ You can see resources in Azure portal

## 🚀 Next Steps

### 1. Build More Compositions
```bash
# Create AKS composition
# Create Storage Account composition
# Create PostgreSQL composition
```

### 2. Set Up GitOps
```bash
# Install ArgoCD or Flux
# Configure auto-sync from your Git repo
```

### 3. Add Composition Functions
```bash
cd functions/naming-convention
# Implement Go-based naming rules
```

### 4. Set Up CI/CD
```bash
# Add GitHub Actions workflows
# Automate validation and deployment
```

### 5. Generate Documentation
```bash
mkdocs serve
# Visit http://localhost:8000
```

## 🔒 Best Practices (Greenfield)

### 1. **Use Devcontainer for Team Consistency**
```json
// Already configured in .devcontainer/devcontainer.json
// Ensures everyone has the same tools and versions
```

### 2. **Version Control Everything**
```bash
# Initialize git if not already done
git init
git add .
git commit -m "Initial Crossplane setup"

# Push to your repo
git remote add origin <your-repo-url>
git push -u origin main
```

### 3. **Secrets Management**
```bash
# NEVER commit azure-credentials.json
# Use External Secrets Operator or Azure Key Vault
# Already in .gitignore
```

### 4. **Environment Separation**
```bash
claims/
├── dev/          # Development claims
├── staging/      # Staging claims
└── prod/         # Production claims (use separate cluster)
```

### 5. **Composition Versioning**
```yaml
# Version your compositions
metadata:
  name: virtualnetwork-azure-v1
  labels:
    version: v1
```

### 6. **Resource Naming Convention**
```yaml
# Use consistent naming with composition functions
# Format: {environment}-{resourceType}-{purpose}-{sequence}
# Example: dev-vnet-apps-001
```

### 7. **Cost Management**
```bash
# Use composition functions to enforce limits
# Add resource tags for cost tracking
# Implement approval workflows for prod
```

### 8. **Documentation**
```bash
# Update docs as you create compositions
mkdocs serve  # Preview locally
mkdocs build  # Generate static site
```

### 9. **Testing Strategy**
```bash
# Validate before applying
./scripts/validate-compositions.sh

# Test in dev environment first
kubectl apply -f claims/dev/test-claim.yaml

# Promote to staging, then prod
```

### 10. **OCI Registry Strategy**

**For pushing to Azure Container Registry:**

```bash
# Build composition functions consistently
# Use devcontainer for builds (eliminates "works on my machine")
docker build -t yourregistry.azurecr.io/function-naming:v1.0.0 .

# Push to ACR
az acr login --name yourregistry
docker push yourregistry.azurecr.io/function-naming:v1.0.0

# Reference in compositions
functionRef:
  name: function-naming
  package: yourregistry.azurecr.io/function-naming:v1.0.0
```

**Devcontainer benefits for OCI:**
- Consistent Docker version
- Same base images for everyone
- No local environment drift
- Safe for CI/CD pipelines

## 🐚 Nushell Integration

Since you're using nushell, create helpful commands:

Create `nu-scripts/crossplane.nu`:
```nushell
# Crossplane helper commands for nushell

# Get all Crossplane resources
export def "xp resources" [] {
  kubectl get managed -o json | from json | get items
}

# Check provider health
export def "xp health" [] {
  kubectl get providers -o json 
  | from json 
  | get items 
  | select metadata.name status.conditions 
  | flatten
}

# Watch claim status
export def "xp watch" [claim: string] {
  kubectl get claim $claim -o json | from json | get status
}

# List all compositions
export def "xp compositions" [] {
  kubectl get compositions -o json 
  | from json 
  | get items 
  | select metadata.name spec.compositeTypeRef.kind
}

# Get Azure resources created
export def "xp azure-resources" [] {
  az resource list --query "[?tags.crossplane=='true']" | from json
}
```

Use in nushell:
```nushell
source nu-scripts/crossplane.nu
xp health
xp compositions
```

## 🆘 Troubleshooting

### Provider not healthy
```bash
kubectl describe provider provider-azure-network
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network
```

### Claim stuck in "Creating"
```bash
kubectl describe virtualnetwork dev-vnet-001
kubectl get events --sort-by='.lastTimestamp'
```

### Azure authentication issues
```bash
# Test service principal
az login --service-principal \
  -u <client-id> \
  -p <client-secret> \
  --tenant <tenant-id>

# Check secret exists
kubectl get secret azure-secret -n crossplane-system
```

## 📚 Additional Resources

- [migration.md](migration.md) - Complete migration guide
- [STRUCTURE.md](STRUCTURE.md) - Repository structure
- [README.md](README.md) - Project overview
- [Crossplane Docs](https://docs.crossplane.io)
- [Upbound Azure Provider](https://marketplace.upbound.io/providers/upbound/provider-azure)

---

**Ready to build your platform!** 🚀

Start with Step 1 and work through each step. Take your time, validate at each step, and enjoy building your infrastructure platform!
