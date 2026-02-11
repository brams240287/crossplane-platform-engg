# Application Stack Compositions

High-level application infrastructure compositions that provision complete application environments.

## Overview

The ApplicationStack API provides a stable abstraction for provisioning complete application infrastructure including:
- Compute resources (Function Apps, App Services)
- Databases (PostgreSQL, MySQL, Redis, CosmosDB)
- Storage (Blob, File Shares)
- Security (Key Vault, Managed Identities)
- Networking (Private Endpoints, NAT Gateway)
- Monitoring (Application Insights, Log Analytics)

## Tiers

### Small Tier
- **Use Case**: Development, testing, small applications
- **Resources**: Up to 2 databases, 3 services
- **SKUs**: Basic/Burstable
- **Budget**: $500/month
- **Features**: Basic monitoring, single region, LRS storage

### Medium Tier
- **Use Case**: Staging, medium-scale applications
- **Resources**: Up to 3 databases, 5 services
- **SKUs**: Standard
- **Budget**: $2,000/month
- **Features**: Auto-scaling, zone redundancy, GRS storage

### Large Tier
- **Use Case**: Production, large-scale applications
- **Resources**: Up to 4 databases, 8 services
- **SKUs**: Premium
- **Budget**: $5,000/month
- **Features**: Multi-region, advanced monitoring, GZRS storage

### Enterprise Tier
- **Use Case**: Mission-critical, enterprise applications
- **Resources**: Up to 5 databases, 10 services
- **SKUs**: Premium with reserved capacity
- **Budget**: $10,000/month
- **Features**: Global distribution, geo-redundancy, 24/7 support

## Example

```yaml
apiVersion: platform.example.com/v1alpha1
kind: ApplicationStack
metadata:
  name: payment-service
  namespace: infra-prod
spec:
  parameters:
    applicationName: payment-svc
    tier: enterprise
    databases:
      - type: postgresql
        size: premium
        highAvailability: true
      - type: redis
        size: premium
    services:
      - name: api
        type: api
        runtime: dotnet-8
        scaling:
          minInstances: 3
          maxInstances: 20
    costCenter: "CC-PAYMENTS-001"
    monthlyBudgetUSD: 8000
```

## Schema Validation

The XRD enforces:
- Naming conventions (lowercase alphanumeric with hyphens)
- Resource limits per tier
- Cost budget limits
- Required fields
- Enum values for types and sizes
