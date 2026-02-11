# Crossplane Azure Infrastructure

This repository contains Crossplane compositions and configurations for managing Azure infrastructure in a declarative, Kubernetes-native way.

## 🏗️ Repository Structure

```
.
├── .github/workflows/       # CI/CD pipelines
├── manifests/              # Crossplane manifests
│   ├── namespaces/         # Kubernetes namespaces
│   ├── providers/          # Crossplane providers
│   ├── provider-configs/   # Provider authentication
│   └── compositions/       # XRDs and Compositions
├── claims/                 # Resource claims by environment
├── functions/              # Composition functions
├── policies/               # Governance policies
├── scripts/                # Automation scripts
├── tests/                  # Unit and integration tests
├── examples/               # Sample configurations
├── docs/                   # Documentation
└── config/                 # GitOps configuration
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster (v1.28+)
- kubectl (v1.28+)
- Crossplane CLI
- Azure subscription with appropriate permissions

### Installation

```bash
# 1. Install Crossplane
./scripts/install-crossplane.sh

# 2. Install Azure providers
./scripts/install-providers.sh

# 3. Configure Azure credentials
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials='{"clientId":"...","clientSecret":"...","subscriptionId":"...","tenantId":"..."}'

# 4. Apply provider configs
kubectl apply -f manifests/provider-configs/

# 5. Deploy compositions
kubectl apply -f manifests/compositions/ -R
```

## 📦 Separate "Container" Approach (Recommended)

The devcontainer image in this repo is a **developer tooling image** (kubectl/helm/kind/az/etc). It should not be the long-term delivery vehicle for your platform IaC.

For a scalable approach, split responsibilities into **three** artifacts:

- **Dev tools image**: used only for local development convenience (VS Code devcontainer). This can evolve independently.
- **KinD cluster images**: pulled by kind at runtime (e.g., `kindest/node:*`). These are not baked into your dev tools image.
- **Crossplane Configuration package (OCI image)**: your platform IaC (XRDs + Compositions + function/provider _dependencies_) built as an `.xpkg` and pushed to ACR.

This lets you build and version your platform configuration like an application container image, and install it into any Crossplane cluster (KinD, AKS, etc.) by applying a `Configuration` resource.

### Local workflow

Build the configuration package (OCI artifact):

```bash
./scripts/build-platform-xpkg.sh
```

Push it to ACR:

```bash
export ACR_NAME=<your-acr-name>
export TAG=v0.0.0-local
./scripts/push-platform-xpkg-acr.sh
```

Install it into your cluster (after Crossplane is installed):

```bash
export ACR_NAME=<your-acr-name>
export TAG=v0.0.0-local

# If your ACR is private, create a pull secret first:
./scripts/create-acr-pull-secret.sh

# Then install the Configuration (set PULL_SECRET_NAME if needed):
export PULL_SECRET_NAME=acr-pull
./scripts/install-platform-configuration.sh
```

### CI/CD workflow

The workflow [.github/workflows/build-push-crossplane-package.yml](.github/workflows/build-push-crossplane-package.yml) builds the `.xpkg` from `manifests/compositions/**` and pushes it to ACR.

Required repo secrets:

- `ACR_NAME`
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (OIDC login)

## 📦 Available Resources

### Infrastructure Resources

- **Network**: Virtual Networks, Subnets, NSGs, NAT Gateways
- **Compute**: Virtual Machines, Scale Sets
- **Kubernetes**: AKS Clusters with node pools
- **Database**: PostgreSQL, MySQL, CosmosDB, Redis Cache
- **Storage**: Storage Accounts, File Shares, Blob Containers
- **Security**: Key Vaults, Managed Identities

### Platform Resources

- **ApplicationStack**: High-level application infrastructure abstraction
- **AzureEnvironment**: Complete environment provisioning

## 🔧 Usage Examples

### Create a simple storage account

```bash
kubectl apply -f examples/simple-vm/
```

### Deploy an AKS cluster with networking

```bash
kubectl apply -f examples/aks-with-networking/
```

### Provision a complete application stack

```yaml
apiVersion: platform.example.com/v1alpha1
kind: ApplicationStack
metadata:
  name: my-app
  namespace: infra-dev
spec:
  parameters:
    applicationName: my-app
    tier: small
    databases:
      - type: postgresql
        size: standard
    services:
      - name: api
        type: api
        runtime: dotnet-8
```

## 🧪 Testing

```bash
# Run unit tests
kubectl kuttl test --config tests/unit/kuttl-config.yaml

# Run integration tests
./scripts/integration-tests.sh dev
```

## 📚 Documentation

- [Getting Started Guide](docs/getting-started/overview.md)
- [Developer Guide](docs/developer-guide/creating-claims.md)
- [Operations Guide](docs/operations-guide/monitoring.md)
- [API Reference](docs/reference/api.md)
- [Migration Guide](migration.md)

## 🛠️ Development

### Validate compositions

```bash
./scripts/validate-compositions.sh
```

### Generate documentation

```bash
python scripts/generate-composition-docs.py \
  --input manifests/compositions \
  --output docs/compositions
```

## 🔒 Security

- All resources use managed identities where possible
- Private endpoints enabled by default for PaaS services
- TLS 1.2+ enforced
- Secrets stored in Azure Key Vault
- RBAC-based access control

## 💰 Cost Management

- Tier-based resource sizing (small, medium, large, enterprise)
- Monthly budget limits enforced via composition functions
- Cost estimation before provisioning
- Resource quotas per tier

## 🤝 Contributing

1. Create a feature branch
2. Add/modify compositions
3. Run validation: `./scripts/validate-compositions.sh`
4. Submit pull request
5. CI/CD will validate and test changes

## 📋 Migration from Pulumi

See [Migration Guide](migration.md) for detailed instructions on migrating from Pulumi to Crossplane.

## 🆘 Support

- [Troubleshooting Guide](docs/developer-guide/troubleshooting.md)
- [Crossplane Slack](https://slack.crossplane.io/)
- Internal team channel: #infrastructure

## 📄 License

Copyright (c) 2026 - All rights reserved
