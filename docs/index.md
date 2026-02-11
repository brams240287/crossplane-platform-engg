# Crossplane Azure Infrastructure

Welcome to the Crossplane Azure Infrastructure documentation. This platform enables declarative, Kubernetes-native infrastructure management for Azure resources.

## 🌟 Key Features

- **Declarative Infrastructure**: Define infrastructure as Kubernetes resources
- **GitOps Ready**: Native integration with ArgoCD and Flux
- **Self-Service**: Developers provision infrastructure via simple YAML
- **Multi-Tier Support**: From small development to enterprise production
- **Cost Control**: Budget limits and tier-based resource sizing
- **Security by Default**: Private endpoints, managed identities, Key Vault integration

## 🚀 Quick Links

- [Getting Started](getting-started/overview.md)
- [Developer Guide](developer-guide/creating-claims.md)
- [Migration from Pulumi](migration.md)
- [API Reference](reference/api.md)

## 📦 Available Resources

### Core Infrastructure
- Virtual Networks with subnets and NSGs
- AKS Clusters with auto-scaling node pools
- PostgreSQL, MySQL, Redis, CosmosDB databases
- Storage accounts with blob and file shares
- Key Vaults with RBAC authorization
- Application Gateways with WAF

### Platform Abstractions
- **ApplicationStack**: Complete application infrastructure
- **AzureEnvironment**: Full environment provisioning

## 🎯 Getting Started

1. [Install Prerequisites](getting-started/prerequisites.md)
2. [Set up Crossplane](getting-started/installation.md)
3. [Create your first claim](developer-guide/creating-claims.md)

## 💡 Example

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

## 🆘 Support

- [Troubleshooting Guide](developer-guide/troubleshooting.md)
- [Operations Guide](operations-guide/monitoring.md)
- Team channel: #infrastructure
