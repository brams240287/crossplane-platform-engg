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
