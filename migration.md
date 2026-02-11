# Pulumi to Crossplane v2 Migration Guide

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Migration Overview](#migration-overview)
3. [Key Differences: Pulumi vs Crossplane](#key-differences-pulumi-vs-crossplane)
4. [Repository Structure](#repository-structure)
5. [Prerequisites](#prerequisites)
6. [Migration Strategy](#migration-strategy)
7. [Resource Mapping](#resource-mapping)
8. [Crossplane Configuration](#crossplane-configuration)
9. [Composition Examples](#composition-examples)
10. [Step-by-Step Migration](#step-by-step-migration)
11. [Testing & Validation](#testing--validation)
12. [Best Practices](#best-practices)
13. [Rollback Strategy](#rollback-strategy)
14. [FAQs & Troubleshooting](#faqs--troubleshooting)

---

## Executive Summary

This document provides a comprehensive migration plan from Pulumi-based Azure infrastructure provisioning to Crossplane v2. The migration enables:

- **Declarative Infrastructure**: Kubernetes-native resource management
- **GitOps Integration**: Native integration with ArgoCD/Flux
- **Self-Service Portals**: Developers can provision infrastructure via Kubernetes APIs
- **Policy Enforcement**: OPA/Gatekeeper integration for governance
- **Multi-Cloud Abstraction**: Unified API across cloud providers

**Migration Timeline**: 8-12 weeks (phased approach)

**Risk Level**: Medium (with proper testing and phased rollout)

---

## Migration Overview

### Current State (Pulumi)

- **Technology**: Pulumi with Python
- **Execution**: CLI-based, manual or CI/CD triggered
- **State Management**: Pulumi state backend (Azure Blob Storage)
- **Configuration**: YAML configuration files consumed by Python code
- **Authentication**: Service Principal with environment variables

### Target State (Crossplane v2)

- **Technology**: Crossplane v2 on Kubernetes
- **Execution**: Declarative, Kubernetes-native controllers
- **State Management**: Kubernetes etcd + External Secrets for sensitive data
- **Configuration**: Kubernetes Custom Resources (XRDs, Compositions, Claims)
- **Authentication**: Workload Identity or Azure Managed Identity

### Why Migrate?

1. **Kubernetes-Native**: Infrastructure as Kubernetes resources
2. **GitOps-Ready**: Native integration with GitOps workflows
3. **Self-Service**: Developers provision via kubectl/UI
4. **Drift Detection**: Continuous reconciliation
5. **Policy Integration**: Kubernetes admission controllers
6. **Multi-Tenancy**: RBAC-based resource isolation
7. **No State File Management**: State stored in Kubernetes etcd

---

## Key Differences: Pulumi vs Crossplane

| Aspect | Pulumi | Crossplane |
|--------|--------|-----------|
| **Execution Model** | Imperative (Python/TypeScript) | Declarative (YAML) |
| **State Management** | External state backend | Kubernetes etcd |
| **Runtime** | CLI (local or CI/CD) | Kubernetes controllers |
| **Configuration** | Programming language | Kubernetes CRDs |
| **Authentication** | Environment variables | Kubernetes Secrets/Workload Identity |
| **Drift Detection** | Manual reconciliation | Continuous reconciliation |
| **Access Control** | External (IAM/AD) | Kubernetes RBAC |
| **GitOps Support** | External integration | Native support |
| **Learning Curve** | Programming knowledge | Kubernetes knowledge |

---

## Repository Structure

### Recommended Crossplane Repository Layout

```
crossplane-infrastructure/
├── README.md
├── .gitignore
├── .github/
│   └── workflows/
│       ├── validate-crossplane.yaml
│       ├── build-configuration.yaml
│       ├── deploy-crossplane.yaml
│       └── generate-docs.yaml
│
├── manifests/
│   ├── namespaces/
│   │   ├── crossplane-system.yaml
│   │   ├── infra-dev.yaml
│   │   ├── infra-staging.yaml
│   │   └── infra-prod.yaml
│   │
│   ├── providers/
│   │   ├── provider-azure-network.yaml
│   │   ├── provider-azure-compute.yaml
│   │   ├── provider-azure-containerservice.yaml
│   │   ├── provider-azure-storage.yaml
│   │   ├── provider-azure-dbforpostgresql.yaml
│   │   ├── provider-azure-keyvault.yaml
│   │   ├── provider-azure-managedidentity.yaml
│   │   ├── provider-helm.yaml
│   │   ├── provider-kubernetes.yaml
│   │   └── provider-github.yaml
│   │
│   ├── provider-configs/
│   │   ├── azure-provider-config.yaml
│   │   ├── helm-provider-config.yaml
│   │   ├── kubernetes-provider-config.yaml
│   │   └── github-provider-config.yaml
│   │
│   └── compositions/
│       ├── network/
│       │   ├── xrd-network.yaml
│       │   ├── composition-network-dev.yaml
│       │   ├── composition-network-prod.yaml
│       │   └── README.md
│       │
│       ├── compute/
│       │   ├── xrd-virtualmachine.yaml
│       │   ├── composition-vm-linux.yaml
│       │   ├── composition-vm-windows.yaml
│       │   └── README.md
│       │
│       ├── kubernetes/
│       │   ├── xrd-aks-cluster.yaml
│       │   ├── composition-aks-private.yaml
│       │   ├── composition-aks-public.yaml
│       │   └── README.md
│       │
│       ├── database/
│       │   ├── xrd-postgres.yaml
│       │   ├── xrd-mysql.yaml
│       │   ├── xrd-cosmosdb.yaml
│       │   ├── composition-postgres-ha.yaml
│       │   ├── composition-postgres-standard.yaml
│       │   ├── composition-mysql-basic.yaml
│       │   └── README.md
│       │
│       ├── storage/
│       │   ├── xrd-storageaccount.yaml
│       │   ├── xrd-fileshare.yaml
│       │   ├── composition-storage-standard.yaml
│       │   ├── composition-storage-premium.yaml
│       │   └── README.md
│       │
│       ├── security/
│       │   ├── xrd-keyvault.yaml
│       │   ├── xrd-managed-identity.yaml
│       │   ├── composition-keyvault.yaml
│       │   └── README.md
│       │
│       ├── application-gateway/
│       │   ├── xrd-appgateway.yaml
│       │   ├── composition-appgateway-waf.yaml
│       │   └── README.md
│       │
│       ├── application-stack/
│       │   ├── xrd-application-stack.yaml
│       │   ├── composition-app-stack-small.yaml
│       │   ├── composition-app-stack-medium.yaml
│       │   ├── composition-app-stack-large.yaml
│       │   ├── composition-app-stack-enterprise.yaml
│       │   └── README.md
│       │
│       ├── platform/
│       │   ├── xrd-azure-environment.yaml
│       │   ├── composition-azure-complete-infra.yaml
│       │   └── README.md
│       │
│       └── github/
│           ├── xrd-github-repo.yaml
│           ├── composition-github-repo.yaml
│           └── README.md
│
├── claims/
│   ├── dev/
│   │   ├── network-claim.yaml
│   │   ├── aks-cluster-claim.yaml
│   │   ├── postgres-claim.yaml
│   │   ├── storage-claim.yaml
│   │   └── application-stacks/
│   │       ├── api-service-claim.yaml
│   │       ├── web-frontend-claim.yaml
│   │       └── worker-service-claim.yaml
│   │
│   ├── staging/
│   │   ├── network-claim.yaml
│   │   ├── aks-cluster-claim.yaml
│   │   └── application-stacks/
│   │       └── ...
│   │
│   └── prod/
│       ├── network-claim.yaml
│       ├── aks-cluster-claim.yaml
│       └── application-stacks/
│           └── ...
│
├── patches/
│   ├── kustomization.yaml
│   ├── dev-patches.yaml
│   ├── staging-patches.yaml
│   └── prod-patches.yaml
│
├── functions/
│   ├── naming-convention/
│   │   ├── function.yaml
│   │   ├── main.go
│   │   ├── go.mod
│   │   └── README.md
│   │
│   ├── tagging/
│   │   ├── function.yaml
│   │   ├── main.go
│   │   └── README.md
│   │
│   ├── resource-limiter/
│   │   ├── function.yaml
│   │   ├── main.go
│   │   └── README.md
│   │
│   └── cost-calculator/
│       ├── function.yaml
│       ├── main.go
│       └── README.md
│
├── policies/
│   ├── cost-limits.yaml
│   ├── naming-conventions.yaml
│   ├── security-standards.yaml
│   └── resource-quotas.yaml
│
├── scripts/
│   ├── install-crossplane.sh
│   ├── install-providers.sh
│   ├── validate-compositions.sh
│   ├── migrate-resource.sh
│   ├── generate-composition-docs.py
│   ├── generate-resource-reference.py
│   ├── integration-tests.sh
│   ├── verify-production.sh
│   └── cleanup.sh
│
├── tests/
│   ├── unit/
│   │   ├── composition-tests.yaml
│   │   ├── xrd-validation-tests.yaml
│   │   └── .coveragerc
│   │
│   ├── integration/
│   │   ├── e2e-tests.yaml
│   │   ├── application-stack-tests.yaml
│   │   └── kuttl-config.yaml
│   │
│   └── fixtures/
│       ├── sample-claims/
│       └── test-data/
│
├── examples/
│   ├── simple-vm/
│   │   ├── README.md
│   │   └── vm-claim.yaml
│   │
│   ├── aks-with-networking/
│   │   ├── README.md
│   │   ├── network-claim.yaml
│   │   └── aks-claim.yaml
│   │
│   ├── complete-environment/
│   │   ├── README.md
│   │   └── environment-claim.yaml
│   │
│   └── application-stack-samples/
│       ├── microservice-api.yaml
│       ├── web-application.yaml
│       └── data-processing-pipeline.yaml
│
├── docs/
│   ├── index.md
│   ├── architecture.md
│   ├── getting-started/
│   │   ├── overview.md
│   │   ├── prerequisites.md
│   │   └── installation.md
│   │
│   ├── developer-guide/
│   │   ├── creating-claims.md
│   │   ├── application-stacks.md
│   │   ├── parameters.md
│   │   └── troubleshooting.md
│   │
│   ├── operations-guide/
│   │   ├── monitoring.md
│   │   ├── backup.md
│   │   ├── upgrades.md
│   │   └── disaster-recovery.md
│   │
│   ├── compositions/
│   │   └── (auto-generated)
│   │
│   ├── reference/
│   │   ├── resource-mapping.md
│   │   └── api.md
│   │
│   └── migration-playbook.md
│
├── config/
│   ├── crossplane.yaml
│   ├── argocd-applications/
│   │   ├── crossplane-providers.yaml
│   │   ├── crossplane-compositions.yaml
│   │   └── infra-claims.yaml
│   │
│   └── flux/
│       ├── kustomization.yaml
│       └── sources.yaml
│
├── Dockerfile.crossplane-cli
├── Dockerfile.validator
├── mkdocs.yml
├── pyproject.toml
└── package.json
```

### Directory Descriptions

- **manifests/**: Core Crossplane configuration
  - **namespaces/**: Kubernetes namespaces for multi-tenancy
  - **providers/**: Crossplane provider installations
  - **provider-configs/**: Provider authentication configuration
  - **compositions/**: Composite resource definitions and compositions

- **claims/**: Environment-specific resource claims (what developers request)
  - **application-stacks/**: High-level application infrastructure claims

- **patches/**: Kustomize patches for environment-specific customization

- **functions/**: Composition functions for advanced logic (Go/Python)
  - **naming-convention/**: Enforce naming standards
  - **tagging/**: Auto-apply tags
  - **resource-limiter/**: Enforce resource quotas
  - **cost-calculator/**: Estimate and enforce cost limits

- **policies/**: Platform governance policies (OPA, Kyverno)

- **scripts/**: Automation scripts for installation and operations

- **tests/**: Unit and integration tests for compositions

- **docs/**: Documentation for developers and operators

- **examples/**: Sample configurations for common use cases

- **config/**: GitOps configuration (ArgoCD/Flux)

---

## Platform Evolution & Application Stacks

### From Single Resources to Capability Collections

As applications evolve, infrastructure requirements grow from simple, single-resource deployments to complex, multi-tier architectures. The Crossplane platform supports this natural evolution by modeling capabilities as **collections** rather than single resources, enabling teams to scale seamlessly without changing their interaction model.

### The ApplicationStack Pattern

The **ApplicationStack API** provides a stable, high-level abstraction that developers use to request infrastructure. Behind this stable interface, the composition logic dynamically provisions multiple resources based on declarative intent:

- **Multiple Function Apps**: API services, background workers, webhooks
- **Different Database Types**: PostgreSQL, MySQL, CosmosDB, Redis Cache
- **Storage Tiers**: Hot, cool, archive storage with different retention policies
- **Networking Components**: Private endpoints, NAT gateways, application gateways
- **Security Resources**: Key Vault, managed identities, certificates
- **Monitoring Stack**: Application Insights, Log Analytics, dashboards

#### Key Principles

1. **Stable API Surface**: Developers interact with a simple, versioned API that doesn't change as complexity grows
2. **Dynamic Provisioning**: Composition logic interprets intent and provisions appropriate resources
3. **Schema Validation**: OpenAPI schemas enforce parameter correctness at submission time
4. **Opinionated Defaults**: Platform team codifies best practices as sensible defaults
5. **Platform-Enforced Limits**: Cost, security, and resource constraints enforced automatically

### ApplicationStack XRD Example

```yaml
# manifests/compositions/application-stack/xrd-application-stack.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xapplicationstacks.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XApplicationStack
    plural: xapplicationstacks
  claimNames:
    kind: ApplicationStack
    plural: applicationstacks
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
                    # High-level application intent
                    applicationName:
                      type: string
                      pattern: "^[a-z][a-z0-9-]{2,28}[a-z0-9]$"
                      description: "Application name (3-30 chars, lowercase alphanumeric with hyphens)"
                    
                    tier:
                      type: string
                      enum: ["small", "medium", "large", "enterprise"]
                      default: "small"
                      description: "Application tier determines resource allocation"
                    
                    region:
                      type: string
                      enum: ["northeurope", "westeurope", "germanywestcentral"]
                      default: "northeurope"
                    
                    # Database requirements (collection)
                    databases:
                      type: array
                      maxItems: 5  # Platform limit
                      items:
                        type: object
                        properties:
                          type:
                            type: string
                            enum: ["postgresql", "mysql", "redis", "cosmosdb"]
                          size:
                            type: string
                            enum: ["basic", "standard", "premium"]
                            default: "standard"
                          highAvailability:
                            type: boolean
                            default: false
                          backupRetentionDays:
                            type: integer
                            minimum: 7
                            maximum: 35
                            default: 7
                    
                    # Compute requirements (collection)
                    services:
                      type: array
                      maxItems: 10  # Platform limit
                      items:
                        type: object
                        properties:
                          name:
                            type: string
                            pattern: "^[a-z][a-z0-9-]{1,18}[a-z0-9]$"
                          type:
                            type: string
                            enum: ["api", "worker", "webhook", "scheduled"]
                          runtime:
                            type: string
                            enum: ["dotnet-8", "node-20", "python-3.11", "java-17"]
                          scaling:
                            type: object
                            properties:
                              minInstances:
                                type: integer
                                minimum: 1
                                maximum: 10
                                default: 1
                              maxInstances:
                                type: integer
                                minimum: 1
                                maximum: 100  # Platform limit
                                default: 5
                    
                    # Storage requirements (collection)
                    storage:
                      type: object
                      properties:
                        blobs:
                          type: array
                          maxItems: 5
                          items:
                            type: object
                            properties:
                              name:
                                type: string
                              tier:
                                type: string
                                enum: ["hot", "cool", "archive"]
                                default: "hot"
                              retentionDays:
                                type: integer
                                minimum: 1
                                maximum: 365
                        fileShares:
                          type: array
                          maxItems: 5
                          items:
                            type: object
                            properties:
                              name:
                                type: string
                              quotaGB:
                                type: integer
                                minimum: 5
                                maximum: 1024  # 1TB limit
                                default: 100
                    
                    # Security & compliance
                    security:
                      type: object
                      properties:
                        enablePrivateEndpoints:
                          type: boolean
                          default: true
                        enableKeyVault:
                          type: boolean
                          default: true
                        managedIdentity:
                          type: boolean
                          default: true
                        certificateNames:
                          type: array
                          items:
                            type: string
                    
                    # Monitoring & observability
                    monitoring:
                      type: object
                      properties:
                        enableApplicationInsights:
                          type: boolean
                          default: true
                        logRetentionDays:
                          type: integer
                          minimum: 30
                          maximum: 730
                          default: 90
                        enableAlerts:
                          type: boolean
                          default: true
                    
                    # Cost controls
                    costCenter:
                      type: string
                      description: "Cost center for billing allocation"
                    
                    monthlyBudgetUSD:
                      type: integer
                      minimum: 50
                      maximum: 50000
                      description: "Maximum monthly budget (enforced by platform)"
                    
                    tags:
                      type: object
                      additionalProperties:
                        type: string
                  
                  required:
                    - applicationName
                    - tier
                    - costCenter
            
            status:
              type: object
              properties:
                # Status outputs
                resourceGroupId:
                  type: string
                applicationUrl:
                  type: string
                databaseEndpoints:
                  type: object
                  additionalProperties:
                    type: string
                storageAccountId:
                  type: string
                keyVaultUrl:
                  type: string
                estimatedMonthlyCost:
                  type: number
                resourceCount:
                  type: integer
                provisioningStatus:
                  type: string
                healthStatus:
                  type: string
```

### Tier-Based Composition

Different tiers provision different resources automatically:

```yaml
# manifests/compositions/application-stack/composition-app-stack-small.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: application-stack-small
  labels:
    tier: small
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XApplicationStack
  
  mode: Pipeline
  pipeline:
    # Step 1: Validate and enforce limits
    - step: validate-limits
      functionRef:
        name: function-resource-limiter
      input:
        apiVersion: limiter.fn.crossplane.io/v1beta1
        kind: Limits
        spec:
          maxDatabases: 2
          maxServices: 3
          maxStorageGB: 500
          maxMonthlyCost: 500
    
    # Step 2: Calculate costs
    - step: calculate-costs
      functionRef:
        name: function-cost-calculator
      input:
        apiVersion: cost.fn.crossplane.io/v1beta1
        kind: CostEstimate
        spec:
          pricingRegion: northeurope
    
    # Step 3: Apply naming conventions
    - step: naming-convention
      functionRef:
        name: function-naming-convention
      input:
        apiVersion: naming.fn.crossplane.io/v1beta1
        kind: NamingPolicy
        spec:
          pattern: "${tier}-${applicationName}-${resourceType}"
          maxLength: 24
    
    # Step 4: Provision resources
    - step: provision-resources
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # Resource Group (foundational)
          - name: resource-group
            base:
              apiVersion: azure.upbound.io/v1beta1
              kind: ResourceGroup
              spec:
                forProvider:
                  location: northeurope
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.tier
                    - fromFieldPath: spec.parameters.applicationName
                  strategy: string
                  string:
                    fmt: "rg-%s-%s"
                toFieldPath: metadata.name
          
          # Key Vault (if enabled)
          - name: keyvault
            base:
              apiVersion: keyvault.azure.upbound.io/v1beta1
              kind: Vault
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  skuName: standard
                  enableSoftDelete: true
                  softDeleteRetentionDays: 7
                  enablePurgeProtection: false  # Small tier
                  enableRbacAuthorization: true
            readinessChecks:
              - type: MatchString
                fieldPath: status.atProvider.properties.provisioningState
                matchString: "Succeeded"
          
          # Managed Identity (if enabled)
          - name: managed-identity
            base:
              apiVersion: managedidentity.azure.upbound.io/v1beta1
              kind: UserAssignedIdentity
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
          
          # Storage Account (standard tier for small)
          - name: storage-account
            base:
              apiVersion: storage.azure.upbound.io/v1beta1
              kind: Account
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  accountTier: Standard
                  accountReplicationType: LRS  # Small tier = LRS
                  enableHttpsTrafficOnly: true
                  minTlsVersion: TLS1_2
          
          # PostgreSQL Database (if requested, 1 max for small tier)
          - name: postgres-server
            base:
              apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
              kind: FlexibleServer
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  skuName: B_Standard_B1ms  # Burstable for small tier
                  storageMb: 32768  # 32GB for small
                  version: "15"
                  highAvailability:
                    mode: Disabled  # No HA for small tier
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.databases[0].type
                toFieldPath: spec.forProvider.skuName
                transforms:
                  - type: map
                    map:
                      postgresql: B_Standard_B1ms
          
          # App Service Plan (small tier)
          - name: app-service-plan
            base:
              apiVersion: web.azure.upbound.io/v1beta1
              kind: ServicePlan
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  osType: Linux
                  skuName: B1  # Basic tier for small
          
          # Function Apps (up to 3 for small tier)
          - name: function-app-api
            base:
              apiVersion: web.azure.upbound.io/v1beta1
              kind: LinuxFunctionApp
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  servicePlanIdSelector:
                    matchControllerRef: true
                  storageAccountNameSelector:
                    matchControllerRef: true
                  identity:
                    - type: UserAssigned
                      identityIdsSelector:
                        matchControllerRef: true
          
          # Application Insights
          - name: app-insights
            base:
              apiVersion: insights.azure.upbound.io/v1beta1
              kind: ApplicationInsights
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  applicationType: web
                  retentionInDays: 90  # Small tier = 90 days
```

### Enterprise Tier Composition

For enterprise tier, the composition automatically provisions more resources:

```yaml
# manifests/compositions/application-stack/composition-app-stack-enterprise.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: application-stack-enterprise
  labels:
    tier: enterprise
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XApplicationStack
  
  mode: Pipeline
  pipeline:
    # Enterprise tier: Higher limits
    - step: validate-limits
      functionRef:
        name: function-resource-limiter
      input:
        apiVersion: limiter.fn.crossplane.io/v1beta1
        kind: Limits
        spec:
          maxDatabases: 5
          maxServices: 10
          maxStorageGB: 5000
          maxMonthlyCost: 10000
    
    - step: provision-resources
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # Enterprise additions:
          # - Zone-redundant PostgreSQL with HA
          # - Premium storage with geo-replication
          # - Application Gateway with WAF
          # - Private endpoints for all PaaS
          # - Azure Front Door for global distribution
          # - Multiple Redis caches for different use cases
          # - Dedicated subnet per service
          # - Azure Monitor with advanced alerting
          # - Azure Policy enforcement
          # - Backup vaults with geo-redundancy
```

### Developer Experience

Developers interact with a simple, stable API regardless of complexity:

```yaml
# claims/prod/application-stacks/payment-service-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: ApplicationStack
metadata:
  name: payment-service
  namespace: infra-prod
spec:
  parameters:
    applicationName: payment-svc
    tier: enterprise  # Automatically gets all enterprise features
    region: northeurope
    
    # Request what you need - platform handles the how
    databases:
      - type: postgresql
        size: premium
        highAvailability: true
        backupRetentionDays: 35
      
      - type: redis
        size: premium
        highAvailability: true
    
    services:
      - name: api
        type: api
        runtime: dotnet-8
        scaling:
          minInstances: 3
          maxInstances: 20
      
      - name: worker
        type: worker
        runtime: dotnet-8
        scaling:
          minInstances: 2
          maxInstances: 10
      
      - name: webhook
        type: webhook
        runtime: dotnet-8
        scaling:
          minInstances: 2
          maxInstances: 5
    
    storage:
      blobs:
        - name: transactions
          tier: hot
          retentionDays: 90
        - name: archives
          tier: archive
          retentionDays: 2555  # 7 years
      
      fileShares:
        - name: config
          quotaGB: 50
        - name: reports
          quotaGB: 500
    
    security:
      enablePrivateEndpoints: true
      enableKeyVault: true
      managedIdentity: true
      certificateNames:
        - payment-api-cert
        - payment-webhook-cert
    
    monitoring:
      enableApplicationInsights: true
      logRetentionDays: 730  # 2 years for compliance
      enableAlerts: true
    
    costCenter: "CC-PAYMENTS-001"
    monthlyBudgetUSD: 8000
    
    tags:
      businessUnit: "payments"
      compliance: "PCI-DSS"
      criticality: "tier-1"
```

### Platform Benefits

#### 1. **Stability Through Abstraction**
- API version stays at `v1alpha1` even as underlying resources evolve
- Composition logic can be updated without developer changes
- New Azure features adopted without breaking changes

#### 2. **Schema Validation**
```yaml
# Validation catches errors at submit time
spec:
  parameters:
    monthlyBudgetUSD: 100000  # ✗ Exceeds maximum (50000)
    services:
      - name: "Invalid Name!"  # ✗ Pattern validation fails
        scaling:
          maxInstances: 200    # ✗ Exceeds platform limit (100)
```

#### 3. **Opinionated Defaults**
- Small tier: Basic SKUs, single-region, LRS storage, 90-day retention
- Medium tier: Standard SKUs, zone-redundant, GRS storage, 180-day retention  
- Large tier: Premium SKUs, multi-region, GZRS storage, 365-day retention
- Enterprise tier: Premium SKUs, global distribution, geo-redundancy, 730-day retention

#### 4. **Platform-Enforced Limits**
- **Resource Limits**: Max databases, services, storage prevent runaway provisioning
- **Cost Limits**: Monthly budget caps with alerts at 50%, 75%, 90%
- **Security Limits**: Force HTTPS, minimum TLS 1.2, private endpoints for prod
- **Compliance Limits**: Minimum backup retention, geo-redundancy for critical data

#### 5. **Progressive Disclosure**
- Start with `tier: small` - get 2-3 basic resources
- Grow to `tier: medium` - get auto-scaling, zone redundancy
- Scale to `tier: large` - get multi-region, advanced monitoring
- Enterprise tier - get full suite with global distribution

### Composition Function: Resource Limiter

```go
// functions/resource-limiter/main.go
package main

import (
    "fmt"
    
    fnv1beta1 "github.com/crossplane/function-sdk-go/proto/v1beta1"
    "github.com/crossplane/function-sdk-go/request"
    "github.com/crossplane/function-sdk-go/response"
)

func main() {
    // Function validates resource limits based on tier
}

func (f *Function) RunFunction(req *fnv1beta1.RunFunctionRequest) (*fnv1beta1.RunFunctionResponse, error) {
    rsp := response.To(req, response.DefaultTTL)
    
    // Extract tier and parameters
    tier := req.Observed.Composite.Resource["spec"]["parameters"]["tier"]
    databases := req.Observed.Composite.Resource["spec"]["parameters"]["databases"]
    services := req.Observed.Composite.Resource["spec"]["parameters"]["services"]
    monthlyCost := req.Observed.Composite.Resource["spec"]["parameters"]["monthlyBudgetUSD"]
    
    // Define limits per tier
    limits := map[string]Limits{
        "small": {MaxDB: 2, MaxServices: 3, MaxCost: 500},
        "medium": {MaxDB: 3, MaxServices: 5, MaxCost: 2000},
        "large": {MaxDB: 4, MaxServices: 8, MaxCost: 5000},
        "enterprise": {MaxDB: 5, MaxServices: 10, MaxCost: 10000},
    }
    
    tierLimits := limits[tier]
    
    // Validate
    if len(databases) > tierLimits.MaxDB {
        response.Fatal(rsp, fmt.Errorf(
            "tier '%s' allows max %d databases, requested %d",
            tier, tierLimits.MaxDB, len(databases)))
        return rsp, nil
    }
    
    if len(services) > tierLimits.MaxServices {
        response.Fatal(rsp, fmt.Errorf(
            "tier '%s' allows max %d services, requested %d",
            tier, tierLimits.MaxServices, len(services)))
        return rsp, nil
    }
    
    if monthlyCost > tierLimits.MaxCost {
        response.Fatal(rsp, fmt.Errorf(
            "tier '%s' allows max $%d monthly budget, requested $%d",
            tier, tierLimits.MaxCost, monthlyCost))
        return rsp, nil
    }
    
    response.Normal(rsp, "Resource limits validated successfully")
    return rsp, nil
}
```

### Evolution Path

```mermaid
graph LR
    A[Single VM] --> B[VM + Database]
    B --> C[App Service + SQL]
    C --> D[ApplicationStack: Small]
    D --> E[ApplicationStack: Medium]
    E --> F[ApplicationStack: Large]
    F --> G[ApplicationStack: Enterprise]
    
    style D fill:#90EE90
    style E fill:#FFD700
    style F fill:#FFA500
    style G fill:#FF6347
```

**Migration Strategy**:
1. **Phase 1**: Migrate individual resources (VMs, databases) to basic compositions
2. **Phase 2**: Introduce ApplicationStack API for new applications (small tier)
3. **Phase 3**: Migrate existing apps to ApplicationStack as they scale
4. **Phase 4**: Enforce ApplicationStack for all new infrastructure

### Key Takeaways

✅ **Stable API**: Developers use same API from prototype to enterprise scale  
✅ **Dynamic Provisioning**: Platform provisions appropriate resources based on tier  
✅ **Built-in Governance**: Schema validation, defaults, and limits enforce standards  
✅ **Cost Control**: Budget limits and tier-based SKUs prevent overspending  
✅ **Security by Default**: Private endpoints, managed identities, Key Vault automatic  
✅ **Scalability**: Grow from 3 resources to 30+ without changing claim structure  

---

## Prerequisites
  - **provider-configs/**: Provider authentication configuration
  - **compositions/**: Composite resource definitions and compositions

- **claims/**: Environment-specific resource claims (what developers request)

- **patches/**: Kustomize patches for environment-specific customization

- **functions/**: Composition functions for advanced logic (Go/Python)

- **scripts/**: Automation scripts for installation and operations

- **tests/**: Unit and integration tests for compositions

- **docs/**: Documentation for developers and operators

- **examples/**: Sample configurations for common use cases

---

## Prerequisites

### Infrastructure Requirements

1. **Kubernetes Cluster**
   - Version: 1.28 or later
   - Recommended: AKS with at least 3 nodes
   - Node Size: Standard_D4s_v3 or larger
   - RBAC enabled

2. **Azure Resources**
   - Service Principal or Managed Identity with Contributor role
   - Resource Groups created
   - Network security configured

3. **Tools**
   - kubectl (v1.28+)
   - helm (v3.12+)
   - crossplane CLI (v1.14+)
   - yq (v4.x)
   - kustomize (v5.x)

### Team Skills

- Kubernetes fundamentals
- YAML and CRD understanding
- Azure resource knowledge
- GitOps concepts (ArgoCD/Flux)

---

## Migration Strategy

### Approach: Phased Migration

We recommend a **phased, resource-by-resource** migration approach:

#### Phase 1: Setup & Pilot (Weeks 1-2)
- Install Crossplane in management cluster
- Configure Azure providers
- Create compositions for non-critical resources
- Pilot with development environment

#### Phase 2: Core Infrastructure (Weeks 3-5)
- Migrate networking resources (VNets, Subnets, NSGs)
- Migrate security resources (Key Vault, Managed Identities)
- Migrate storage resources

#### Phase 3: Compute & Databases (Weeks 6-8)
- Migrate VM resources
- Migrate PostgreSQL databases
- Migrate Redis caches

#### Phase 4: Kubernetes & Applications (Weeks 9-10)
- Migrate AKS clusters
- Migrate Application Gateways
- Configure persistent volumes

#### Phase 5: Validation & Cutover (Weeks 11-12)
- End-to-end testing
- Production cutover
- Decommission Pulumi stack

### Migration Patterns

#### Pattern 1: Green-Field Migration
- Create new resources with Crossplane
- Migrate applications to new resources
- Decommission old resources

#### Pattern 2: Import Existing Resources
- Use provider import feature
- Annotate existing resources
- Gradually adopt Crossplane management

#### Pattern 3: Hybrid Approach (Recommended)
- Non-critical resources: Green-field
- Critical resources: Import existing
- Gradual transition

---

## Resource Mapping

### Network Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:network:VirtualNetwork` | `network.azure.upbound.io/v1beta1/VirtualNetwork` | provider-azure-network | Direct mapping |
| `azure-native:network:Subnet` | `network.azure.upbound.io/v1beta1/Subnet` | provider-azure-network | Supports delegation |
| `azure-native:network:NetworkSecurityGroup` | `network.azure.upbound.io/v1beta1/SecurityGroup` | provider-azure-network | Rules as inline |
| `azure-native:network:NatGateway` | `network.azure.upbound.io/v1beta1/NATGateway` | provider-azure-network | - |
| `azure-native:network:VirtualNetworkPeering` | `network.azure.upbound.io/v1beta1/VirtualNetworkPeering` | provider-azure-network | Bi-directional support |
| `azure-native:network:PublicIPAddress` | `network.azure.upbound.io/v1beta1/PublicIP` | provider-azure-network | - |

### Compute Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:compute:VirtualMachine` | `compute.azure.upbound.io/v1beta1/LinuxVirtualMachine` | provider-azure-compute | OS-specific |
| `azure-native:compute:VirtualMachineScaleSet` | `compute.azure.upbound.io/v1beta1/LinuxVirtualMachineScaleSet` | provider-azure-compute | Auto-scaling support |
| `azure-native:compute:ProximityPlacementGroup` | `compute.azure.upbound.io/v1beta1/ProximityPlacementGroup` | provider-azure-compute | - |
| `azure-native:compute:SSHPublicKey` | `compute.azure.upbound.io/v1beta1/SSHPublicKey` | provider-azure-compute | - |

### Kubernetes Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:containerservice:ManagedCluster` | `containerservice.azure.upbound.io/v1beta1/KubernetesCluster` | provider-azure-containerservice | AKS cluster |
| Agent Pools | `containerservice.azure.upbound.io/v1beta1/KubernetesClusterNodePool` | provider-azure-containerservice | Separate resource |
| ACR Integration | Configure via composition | - | Use managed identity |

### Storage Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:storage:StorageAccount` | `storage.azure.upbound.io/v1beta1/Account` | provider-azure-storage | - |
| `azure-native:storage:FileShare` | `storage.azure.upbound.io/v1beta1/Share` | provider-azure-storage | Requires storage account |
| `azure-native:storage:BlobContainer` | `storage.azure.upbound.io/v1beta1/Container` | provider-azure-storage | - |

### Database Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:dbforpostgresql:FlexibleServer` | `dbforpostgresql.azure.upbound.io/v1beta1/FlexibleServer` | provider-azure-dbforpostgresql | - |
| PostgreSQL Database | `dbforpostgresql.azure.upbound.io/v1beta1/FlexibleServerDatabase` | provider-azure-dbforpostgresql | - |
| PostgreSQL Configuration | `dbforpostgresql.azure.upbound.io/v1beta1/FlexibleServerConfiguration` | provider-azure-dbforpostgresql | Per parameter |

### Security Resources

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:keyvault:Vault` | `keyvault.azure.upbound.io/v1beta1/Vault` | provider-azure-keyvault | - |
| Key Vault Secret | `keyvault.azure.upbound.io/v1beta1/Secret` | provider-azure-keyvault | Use External Secrets Operator |
| Managed Identity | `managedidentity.azure.upbound.io/v1beta1/UserAssignedIdentity` | provider-azure-managedidentity | - |

### Application Gateway

| Pulumi Resource | Crossplane Resource | Provider | Notes |
|-----------------|---------------------|----------|-------|
| `azure-native:network:ApplicationGateway` | `network.azure.upbound.io/v1beta1/ApplicationGateway` | provider-azure-network | Complex config |
| WAF Policy | `network.azure.upbound.io/v1beta1/WebApplicationFirewallPolicy` | provider-azure-network | - |

---

## Crossplane Configuration

### Step 1: Install Crossplane

```bash
#!/bin/bash
# install-crossplane.sh

# Add Crossplane Helm repository
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane \
  crossplane-stable/crossplane \
  --namespace crossplane-system \
  --create-namespace \
  --version 1.14.0 \
  --set args='{--enable-composition-functions,--enable-composition-webhook-schema-validation}' \
  --wait

# Verify installation
kubectl wait --for=condition=Available deployment/crossplane -n crossplane-system --timeout=300s

# Install Crossplane CLI
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin/

echo "Crossplane installed successfully!"
```

### Step 2: Install Azure Providers

```yaml
# manifests/providers/provider-azure-network.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: azure-provider-config
spec:
  podSecurityContext:
    fsGroup: 2000
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 2000
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
```

```yaml
# manifests/providers/provider-azure-compute.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-compute
spec:
  package: xpkg.upbound.io/upbound/provider-azure-compute:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
```

```yaml
# manifests/providers/provider-azure-containerservice.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-containerservice
spec:
  package: xpkg.upbound.io/upbound/provider-azure-containerservice:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
```

```yaml
# manifests/providers/provider-azure-storage.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-storage
spec:
  package: xpkg.upbound.io/upbound/provider-azure-storage:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
```

```yaml
# manifests/providers/provider-azure-dbforpostgresql.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-dbforpostgresql
spec:
  package: xpkg.upbound.io/upbound/provider-azure-dbforpostgresql:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
```

```yaml
# manifests/providers/provider-azure-keyvault.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-keyvault
spec:
  package: xpkg.upbound.io/upbound/provider-azure-keyvault:v0.42.0
  packagePullPolicy: IfNotPresent
  controllerConfigRef:
    name: azure-provider-config
```

### Step 3: Configure Provider Authentication

```yaml
# manifests/provider-configs/azure-provider-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: azure-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    {
      "clientId": "${AZURE_CLIENT_ID}",
      "clientSecret": "${AZURE_CLIENT_SECRET}",
      "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
      "tenantId": "${AZURE_TENANT_ID}",
      "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
      "resourceManagerEndpointUrl": "https://management.azure.com/",
      "activeDirectoryGraphResourceId": "https://graph.windows.net/",
      "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
      "galleryEndpointUrl": "https://gallery.azure.com/",
      "managementEndpointUrl": "https://management.core.windows.net/"
    }
---
apiVersion: azure.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      name: azure-credentials
      namespace: crossplane-system
      key: credentials
```

**Apply Configuration:**

```bash
# Create secret with Azure credentials
kubectl create secret generic azure-credentials \
  -n crossplane-system \
  --from-literal=credentials="$(cat <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "tenantId": "${AZURE_TENANT_ID}",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
EOF
)"

# Apply ProviderConfig
kubectl apply -f manifests/provider-configs/azure-provider-config.yaml
```

---

## Composition Examples

### Example 1: Virtual Network Composition

```yaml
# manifests/compositions/network/xrd-network.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xazurenetworks.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XAzureNetwork
    plural: xazurenetworks
  claimNames:
    kind: AzureNetwork
    plural: azurenetworks
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
                    region:
                      type: string
                      description: Azure region
                    resourceGroup:
                      type: string
                      description: Resource group name
                    vnetName:
                      type: string
                      description: Virtual network name
                    addressSpace:
                      type: array
                      items:
                        type: string
                      description: VNet address space
                    subnets:
                      type: array
                      items:
                        type: object
                        properties:
                          name:
                            type: string
                          addressPrefix:
                            type: string
                          serviceEndpoints:
                            type: array
                            items:
                              type: string
                          delegations:
                            type: array
                            items:
                              type: string
                    tags:
                      type: object
                      additionalProperties:
                        type: string
                  required:
                    - region
                    - resourceGroup
                    - vnetName
                    - addressSpace
              required:
                - parameters
            status:
              type: object
              properties:
                vnetId:
                  type: string
                subnetIds:
                  type: object
                  additionalProperties:
                    type: string
```

```yaml
# manifests/compositions/network/composition-network-dev.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: azure-network-dev
  labels:
    environment: dev
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XAzureNetwork
  
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # Resource Group
          - name: resourcegroup
            base:
              apiVersion: azure.upbound.io/v1beta1
              kind: ResourceGroup
              spec:
                forProvider:
                  location: northeurope
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.resourceGroup
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.tags
                toFieldPath: spec.forProvider.tags
          
          # Virtual Network
          - name: virtualnetwork
            base:
              apiVersion: network.azure.upbound.io/v1beta1
              kind: VirtualNetwork
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.vnetName
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.addressSpace
                toFieldPath: spec.forProvider.addressSpace
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.tags
                toFieldPath: spec.forProvider.tags
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.id
                toFieldPath: status.vnetId
          
          # Subnets (dynamic based on input)
          - name: subnet-aks
            base:
              apiVersion: network.azure.upbound.io/v1beta1
              kind: Subnet
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  virtualNetworkNameSelector:
                    matchControllerRef: true
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.subnets[0].name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.subnets[0].addressPrefix
                toFieldPath: spec.forProvider.addressPrefixes[0]
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.subnets[0].serviceEndpoints
                toFieldPath: spec.forProvider.serviceEndpoints
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.id
                toFieldPath: status.subnetIds.aks
          
          # Network Security Group
          - name: nsg
            base:
              apiVersion: network.azure.upbound.io/v1beta1
              kind: SecurityGroup
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  securityRule:
                    - name: AllowAzureServices
                      priority: 1000
                      direction: Outbound
                      access: Allow
                      protocol: "*"
                      sourcePortRange: "*"
                      destinationPortRange: "*"
                      sourceAddressPrefix: "*"
                      destinationAddressPrefix: AzureCloud
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.vnetName
                  strategy: string
                  string:
                    fmt: "%s-nsg"
                toFieldPath: metadata.name
          
          # NAT Gateway
          - name: natgateway-pip
            base:
              apiVersion: network.azure.upbound.io/v1beta1
              kind: PublicIP
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  allocationMethod: Static
                  sku: Standard
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.vnetName
                  strategy: string
                  string:
                    fmt: "%s-nat-pip"
                toFieldPath: metadata.name
          
          - name: natgateway
            base:
              apiVersion: network.azure.upbound.io/v1beta1
              kind: NATGateway
              spec:
                forProvider:
                  resourceGroupNameSelector:
                    matchControllerRef: true
                  skuName: Standard
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.vnetName
                  strategy: string
                  string:
                    fmt: "%s-nat"
                toFieldPath: metadata.name
```

### Example 2: AKS Cluster Composition

```yaml
# manifests/compositions/kubernetes/xrd-aks-cluster.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xaksclusters.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XAKSCluster
    plural: xaksclusters
  claimNames:
    kind: AKSCluster
    plural: aksclusters
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
                    region:
                      type: string
                    resourceGroup:
                      type: string
                    clusterName:
                      type: string
                    kubernetesVersion:
                      type: string
                      default: "1.28"
                    networkProfile:
                      type: object
                      properties:
                        vnetSubnetId:
                          type: string
                        serviceCidr:
                          type: string
                        dnsServiceIp:
                          type: string
                        dockerBridgeCidr:
                          type: string
                    defaultNodePool:
                      type: object
                      properties:
                        name:
                          type: string
                          default: "system"
                        vmSize:
                          type: string
                          default: "Standard_D2s_v3"
                        nodeCount:
                          type: integer
                          default: 3
                        enableAutoScaling:
                          type: boolean
                          default: false
                    additionalNodePools:
                      type: array
                      items:
                        type: object
                        properties:
                          name:
                            type: string
                          vmSize:
                            type: string
                          minCount:
                            type: integer
                          maxCount:
                            type: integer
                          enableAutoScaling:
                            type: boolean
                    enablePrivateCluster:
                      type: boolean
                      default: true
                    managedIdentityName:
                      type: string
                    tags:
                      type: object
                      additionalProperties:
                        type: string
                  required:
                    - region
                    - resourceGroup
                    - clusterName
              required:
                - parameters
            status:
              type: object
              properties:
                clusterId:
                  type: string
                fqdn:
                  type: string
                kubeconfig:
                  type: string
```

```yaml
# manifests/compositions/kubernetes/composition-aks-private.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: aks-private-cluster
  labels:
    cluster-type: private
    provider: azure
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XAKSCluster
  
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # Managed Identity
          - name: managed-identity
            base:
              apiVersion: managedidentity.azure.upbound.io/v1beta1
              kind: UserAssignedIdentity
              spec:
                forProvider:
                  resourceGroupName: ""
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.resourceGroup
                toFieldPath: spec.forProvider.resourceGroupName
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.managedIdentityName
                toFieldPath: metadata.name
          
          # AKS Cluster
          - name: aks-cluster
            base:
              apiVersion: containerservice.azure.upbound.io/v1beta1
              kind: KubernetesCluster
              spec:
                forProvider:
                  resourceGroupName: ""
                  dnsPrefix: ""
                  privateClusterEnabled: true
                  networkProfile:
                    - networkPlugin: azure
                      networkPolicy: azure
                      loadBalancerSku: standard
                      outboundType: userAssignedNATGateway
                  identity:
                    - type: UserAssigned
                      identityIds: []
                  defaultNodePool:
                    - name: system
                      enableAutoScaling: false
                      maxPods: 110
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.resourceGroup
                toFieldPath: spec.forProvider.resourceGroupName
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.clusterName
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.clusterName
                toFieldPath: spec.forProvider.dnsPrefix
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.kubernetesVersion
                toFieldPath: spec.forProvider.kubernetesVersion
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.enablePrivateCluster
                toFieldPath: spec.forProvider.privateClusterEnabled
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.networkProfile.vnetSubnetId
                toFieldPath: spec.forProvider.defaultNodePool[0].vnetSubnetId
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.networkProfile.serviceCidr
                toFieldPath: spec.forProvider.networkProfile[0].serviceCidr
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.networkProfile.dnsServiceIp
                toFieldPath: spec.forProvider.networkProfile[0].dnsServiceIp
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.networkProfile.dockerBridgeCidr
                toFieldPath: spec.forProvider.networkProfile[0].dockerBridgeCidr
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.defaultNodePool.name
                toFieldPath: spec.forProvider.defaultNodePool[0].name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.defaultNodePool.vmSize
                toFieldPath: spec.forProvider.defaultNodePool[0].vmSize
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.defaultNodePool.nodeCount
                toFieldPath: spec.forProvider.defaultNodePool[0].nodeCount
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.defaultNodePool.enableAutoScaling
                toFieldPath: spec.forProvider.defaultNodePool[0].enableAutoScaling
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.tags
                toFieldPath: spec.forProvider.tags
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.id
                toFieldPath: status.clusterId
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.fqdn
                toFieldPath: status.fqdn
          
          # Additional Node Pools (example for worker pool)
          - name: worker-nodepool
            base:
              apiVersion: containerservice.azure.upbound.io/v1beta1
              kind: KubernetesClusterNodePool
              spec:
                forProvider:
                  kubernetesClusterIdSelector:
                    matchControllerRef: true
                  enableAutoScaling: true
                  maxPods: 110
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.additionalNodePools[0].name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.additionalNodePools[0].vmSize
                toFieldPath: spec.forProvider.vmSize
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.additionalNodePools[0].minCount
                toFieldPath: spec.forProvider.minCount
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.additionalNodePools[0].maxCount
                toFieldPath: spec.forProvider.maxCount
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.networkProfile.vnetSubnetId
                toFieldPath: spec.forProvider.vnetSubnetId
```

### Example 3: PostgreSQL Flexible Server Composition

```yaml
# manifests/compositions/database/xrd-postgres.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xpostgresinstances.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XPostgresInstance
    plural: xpostgresinstances
  claimNames:
    kind: PostgresInstance
    plural: postgresinstances
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
                    region:
                      type: string
                    resourceGroup:
                      type: string
                    serverName:
                      type: string
                    version:
                      type: string
                      default: "15"
                      enum: ["13", "14", "15", "16"]
                    sku:
                      type: string
                      default: "GP_Standard_D2s_v3"
                    storageMb:
                      type: integer
                      default: 131072
                    subnetId:
                      type: string
                    adminUsername:
                      type: string
                      default: "psqladmin"
                    databases:
                      type: array
                      items:
                        type: object
                        properties:
                          name:
                            type: string
                          charset:
                            type: string
                            default: "UTF8"
                          collation:
                            type: string
                            default: "en_US.utf8"
                    highAvailability:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: false
                        mode:
                          type: string
                          default: "ZoneRedundant"
                    backupRetentionDays:
                      type: integer
                      default: 7
                    tags:
                      type: object
                      additionalProperties:
                        type: string
                  required:
                    - region
                    - resourceGroup
                    - serverName
                    - subnetId
              required:
                - parameters
            status:
              type: object
              properties:
                serverId:
                  type: string
                fqdn:
                  type: string
```

```yaml
# manifests/compositions/database/composition-postgres-ha.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: postgres-flexible-ha
  labels:
    provider: azure
    ha: enabled
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XPostgresInstance
  
  writeConnectionSecretsToNamespace: crossplane-system
  
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # PostgreSQL Flexible Server
          - name: postgres-server
            base:
              apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
              kind: FlexibleServer
              spec:
                forProvider:
                  resourceGroupName: ""
                  administratorLogin: psqladmin
                  administratorPasswordSecretRef:
                    name: ""
                    namespace: crossplane-system
                    key: password
                  skuName: ""
                  storageMb: 131072
                  version: "15"
                  zone: "1"
                writeConnectionSecretToRef:
                  namespace: crossplane-system
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.region
                toFieldPath: spec.forProvider.location
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.resourceGroup
                toFieldPath: spec.forProvider.resourceGroupName
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.serverName
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.adminUsername
                toFieldPath: spec.forProvider.administratorLogin
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.version
                toFieldPath: spec.forProvider.version
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.sku
                toFieldPath: spec.forProvider.skuName
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.storageMb
                toFieldPath: spec.forProvider.storageMb
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.subnetId
                toFieldPath: spec.forProvider.delegatedSubnetId
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.highAvailability.enabled
                toFieldPath: spec.forProvider.highAvailability[0].mode
                transforms:
                  - type: map
                    map:
                      "true": "ZoneRedundant"
                      "false": ""
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.backupRetentionDays
                toFieldPath: spec.forProvider.backupRetentionDays
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.tags
                toFieldPath: spec.forProvider.tags
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.id
                toFieldPath: status.serverId
              - type: ToCompositeFieldPath
                fromFieldPath: status.atProvider.fqdn
                toFieldPath: status.fqdn
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.serverName
                  strategy: string
                  string:
                    fmt: "%s-password"
                toFieldPath: spec.forProvider.administratorPasswordSecretRef.name
              - type: CombineFromComposite
                combine:
                  variables:
                    - fromFieldPath: spec.parameters.serverName
                  strategy: string
                  string:
                    fmt: "%s-connection"
                toFieldPath: spec.writeConnectionSecretToRef.name
          
          # Database 1
          - name: database-1
            base:
              apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
              kind: FlexibleServerDatabase
              spec:
                forProvider:
                  serverIdSelector:
                    matchControllerRef: true
                  charset: UTF8
                  collation: en_US.utf8
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.databases[0].name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.databases[0].charset
                toFieldPath: spec.forProvider.charset
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.databases[0].collation
                toFieldPath: spec.forProvider.collation
          
          # Configuration - max_connections
          - name: config-max-connections
            base:
              apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
              kind: FlexibleServerConfiguration
              metadata:
                name: max-connections
              spec:
                forProvider:
                  serverIdSelector:
                    matchControllerRef: true
                  name: max_connections
                  value: "300"
          
          # Configuration - shared_buffers
          - name: config-shared-buffers
            base:
              apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
              kind: FlexibleServerConfiguration
              metadata:
                name: shared-buffers
              spec:
                forProvider:
                  serverIdSelector:
                    matchControllerRef: true
                  name: shared_buffers
                  value: "518144"
```

### Example 4: Complete Platform Composition

```yaml
# manifests/compositions/platform/xrd-azure-environment.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xazureenvironments.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XAzureEnvironment
    plural: xazureenvironments
  claimNames:
    kind: AzureEnvironment
    plural: azureenvironments
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
                    projectName:
                      type: string
                    environment:
                      type: string
                      enum: ["dev", "staging", "prod"]
                    region:
                      type: string
                      default: "northeurope"
                    # Network configuration
                    vnetAddressSpace:
                      type: string
                      default: "10.0.0.0/16"
                    # AKS configuration
                    aksEnabled:
                      type: boolean
                      default: true
                    kubernetesVersion:
                      type: string
                      default: "1.28"
                    # Database configuration
                    postgresEnabled:
                      type: boolean
                      default: true
                    postgresVersion:
                      type: string
                      default: "15"
                    # Storage configuration
                    storageEnabled:
                      type: boolean
                      default: true
                    # Tags
                    tags:
                      type: object
                      additionalProperties:
                        type: string
                  required:
                    - projectName
                    - environment
              required:
                - parameters
```

---

## Step-by-Step Migration

### Phase 1: Setup & Pilot (Weeks 1-2)

#### Week 1: Infrastructure Setup

**Day 1-2: Install Crossplane**

```bash
# 1. Create management AKS cluster (if not exists)
az aks create \
  --resource-group rg-crossplane-mgmt \
  --name aks-crossplane-mgmt \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-managed-identity \
  --network-plugin azure

# 2. Get credentials
az aks get-credentials \
  --resource-group rg-crossplane-mgmt \
  --name aks-crossplane-mgmt

# 3. Install Crossplane
./scripts/install-crossplane.sh

# 4. Verify installation
kubectl get pods -n crossplane-system
```

**Day 3-4: Install Providers**

```bash
# Apply all provider manifests
kubectl apply -f manifests/providers/

# Wait for providers to be ready
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io --all --timeout=300s

# Configure authentication
kubectl apply -f manifests/provider-configs/azure-provider-config.yaml

# Verify provider configs
kubectl get providerconfigs
```

**Day 5: Create First Composition (Resource Group)**

```bash
# Create simple resource group composition for testing
kubectl apply -f manifests/compositions/basic/xrd-resourcegroup.yaml
kubectl apply -f manifests/compositions/basic/composition-resourcegroup.yaml

# Create test claim
kubectl apply -f claims/dev/test-resourcegroup-claim.yaml

# Watch resource creation
kubectl get managed
watch kubectl get resourcegroup
```

#### Week 2: Pilot Resources

**Day 1-3: Migrate Non-Critical Resources**

1. **Storage Account (Pilot)**

```yaml
# claims/dev/storage-pilot-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: StorageAccount
metadata:
  name: pilot-storage
  namespace: infra-dev
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-pilot-dev
    accountName: stpilotdev001
    sku: Standard_LRS
    tags:
      environment: dev
      pilot: "true"
      managedBy: crossplane
```

Apply and validate:

```bash
kubectl apply -f claims/dev/storage-pilot-claim.yaml
kubectl get storageaccount pilot-storage -n infra-dev -o yaml
kubectl describe storageaccount pilot-storage -n infra-dev

# Check in Azure Portal
az storage account show --name stpilotdev001 --resource-group rg-pilot-dev
```

2. **Virtual Network (Pilot)**

```yaml
# claims/dev/network-pilot-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: AzureNetwork
metadata:
  name: pilot-network
  namespace: infra-dev
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-pilot-dev
    vnetName: vnet-pilot-dev
    addressSpace:
      - "10.100.0.0/16"
    subnets:
      - name: snet-aks
        addressPrefix: "10.100.0.0/24"
        serviceEndpoints:
          - Microsoft.Storage
          - Microsoft.KeyVault
      - name: snet-db
        addressPrefix: "10.100.1.0/24"
        delegations:
          - Microsoft.DBforPostgreSQL/flexibleServers
    tags:
      environment: dev
      pilot: "true"
```

**Day 4-5: Validation & Documentation**

- Test resource creation/update/deletion
- Document learnings
- Refine compositions based on feedback
- Create developer guide

---

### Phase 2: Core Infrastructure (Weeks 3-5)

#### Week 3: Networking Migration

**Approach**: Create new networking resources in parallel

**Migration Steps**:

1. **Export Existing Configuration**

```bash
# Export current Pulumi config
pulumi stack export --file pulumi-export.json

# Extract network configuration
jq '.deployment.resources[] | select(.type | contains("network"))' pulumi-export.json > network-resources.json
```

2. **Create Crossplane Claims**

```bash
# Generate claims from Pulumi export
python scripts/convert-pulumi-to-crossplane.py network-resources.json > claims/prod/network-claim.yaml
```

3. **Apply and Validate**

```bash
kubectl apply -f claims/prod/network-claim.yaml
kubectl wait --for=condition=Ready azurenetwork/prod-network -n infra-prod --timeout=600s

# Verify resources in Azure
az network vnet show --name vnet-prod --resource-group rg-prod
```

#### Week 4: Security Resources

1. **Key Vault Migration**

```yaml
# claims/prod/keyvault-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: KeyVault
metadata:
  name: prod-keyvault
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    vaultName: kvprod001
    skuName: standard
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionDays: 7
    networkAcls:
      defaultAction: Deny
      virtualNetworkSubnetIds:
        - /subscriptions/.../subnets/snet-aks
    tags:
      environment: prod
      managedBy: crossplane
```

2. **Managed Identities**

```yaml
# claims/prod/managed-identity-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: ManagedIdentity
metadata:
  name: prod-aks-identity
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    identityName: mid-prod-aks
    roleAssignments:
      - scope: /subscriptions/.../resourceGroups/rg-prod-main
        role: Contributor
```

#### Week 5: Storage Resources

1. **Storage Accounts with File Shares**

```bash
# Apply storage composition
kubectl apply -f claims/prod/storage-claim.yaml

# Wait for resources
kubectl wait --for=condition=Ready storageaccount/prod-storage -n infra-prod

# Verify file shares
az storage share list --account-name stprod001
```

---

### Phase 3: Compute & Databases (Weeks 6-8)

#### Week 6-7: Database Migration

**Option A: Blue-Green Migration (Recommended for Production)**

1. **Create New PostgreSQL Server**

```yaml
# claims/prod/postgres-new-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: PostgresInstance
metadata:
  name: prod-postgres-new
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    serverName: pg-prod-new
    version: "15"
    sku: GP_Standard_D4ds_v4
    storageMb: 262144
    subnetId: /subscriptions/.../subnets/snet-db
    databases:
      - name: PDA
        charset: UTF8
        collation: en_US.utf8
      - name: MES
        charset: UTF8
        collation: en_US.utf8
    highAvailability:
      enabled: true
      mode: ZoneRedundant
    backupRetentionDays: 30
```

2. **Data Migration**

```bash
# Dump from old server
pg_dump -h pg-prod-old.postgres.database.azure.com -U admin -d PDA -f pda_dump.sql

# Restore to new server
psql -h pg-prod-new.postgres.database.azure.com -U psqladmin -d PDA -f pda_dump.sql

# Validate data
psql -h pg-prod-new.postgres.database.azure.com -U psqladmin -d PDA -c "\dt"
```

3. **Cutover**

```bash
# Update application connection strings
kubectl set env deployment/app DATABASE_HOST=pg-prod-new.postgres.database.azure.com

# Monitor application
kubectl logs -f deployment/app

# After validation, decommission old server
pulumi destroy --target azure-native:dbforpostgresql:FlexibleServer::pg-prod-old
```

**Option B: Import Existing Resources**

```yaml
# Import existing PostgreSQL server
apiVersion: dbforpostgresql.azure.upbound.io/v1beta1
kind: FlexibleServer
metadata:
  name: pg-prod-existing
  annotations:
    crossplane.io/external-name: pg-prod
spec:
  forProvider:
    resourceGroupName: rg-prod-main
  managementPolicy: ObserveOnly  # Start with observe-only
```

```bash
# Apply import
kubectl apply -f postgres-import.yaml

# Verify import
kubectl describe flexibleserver pg-prod-existing

# Change to full management
kubectl patch flexibleserver pg-prod-existing \
  --type merge \
  --patch '{"spec":{"managementPolicy":"Default"}}'
```

#### Week 8: Virtual Machine Migration

```yaml
# claims/prod/jumphost-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: VirtualMachine
metadata:
  name: prod-jumphost
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    vmName: vm-jumphost-prod
    vmSize: Standard_B2s
    osType: Linux
    imageReference:
      publisher: Canonical
      offer: 0001-com-ubuntu-server-jammy
      sku: 22_04-lts-gen2
      version: latest
    subnetId: /subscriptions/.../subnets/snet-mgmt
    publicIpEnabled: true
    sshKeyPath: /secrets/ssh-public-key
    managedIdentityId: /subscriptions/.../mid-prod-vm
```

---

### Phase 4: Kubernetes & Applications (Weeks 9-10)

#### Week 9: AKS Cluster Migration

**Strategy**: Create new cluster, migrate workloads, decommission old

1. **Create New AKS Cluster**

```yaml
# claims/prod/aks-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: AKSCluster
metadata:
  name: prod-aks-new
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    clusterName: aks-prod-new
    kubernetesVersion: "1.28"
    networkProfile:
      vnetSubnetId: /subscriptions/.../subnets/snet-aks
      serviceCidr: 10.0.0.0/16
      dnsServiceIp: 10.0.0.10
      dockerBridgeCidr: 172.17.0.1/16
    defaultNodePool:
      name: system
      vmSize: Standard_D4s_v3
      nodeCount: 3
      enableAutoScaling: false
    additionalNodePools:
      - name: worker
        vmSize: Standard_D8s_v3
        minCount: 2
        maxCount: 10
        enableAutoScaling: true
    enablePrivateCluster: true
    managedIdentityName: mid-prod-aks
    tags:
      environment: prod
      managedBy: crossplane
```

2. **Wait for Cluster Ready**

```bash
kubectl wait --for=condition=Ready akscluster/prod-aks-new -n infra-prod --timeout=1800s

# Get kubeconfig
kubectl get secret prod-aks-new-connection -n crossplane-system -o jsonpath='{.data.kubeconfig}' | base64 -d > kubeconfig-new

# Set context
export KUBECONFIG=kubeconfig-new
kubectl get nodes
```

3. **Migrate Workloads**

```bash
# Velero backup from old cluster
velero backup create pre-migration-backup --include-namespaces app-ns

# Restore to new cluster
export KUBECONFIG=kubeconfig-new
velero restore create --from-backup pre-migration-backup

# Validate applications
kubectl get pods -A
kubectl get svc -A
```

#### Week 10: Application Gateway

```yaml
# claims/prod/appgateway-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: ApplicationGateway
metadata:
  name: prod-appgw
  namespace: infra-prod
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-prod-main
    gatewayName: appgw-prod
    sku:
      name: WAF_v2
      tier: WAF_v2
      capacity: 2
    subnetId: /subscriptions/.../subnets/snet-appgw
    publicIpEnabled: true
    wafPolicy:
      enabled: true
      mode: Prevention
      ruleSetType: OWASP
      ruleSetVersion: "3.2"
```

---

### Phase 5: Validation & Cutover (Weeks 11-12)

#### Week 11: End-to-End Testing

**Test Scenarios**:

1. **Resource Creation Test**

```bash
# Create test environment
kubectl apply -f claims/test/complete-environment-claim.yaml

# Validate all resources created
kubectl get managed -l environment=test

# Check Azure resources
az resource list --tag environment=test
```

2. **Update Test**

```bash
# Update resource (e.g., scale AKS nodes)
kubectl patch akscluster test-aks -n infra-test \
  --type merge \
  --patch '{"spec":{"parameters":{"defaultNodePool":{"nodeCount":5}}}}'

# Verify update propagated
az aks show --name aks-test --resource-group rg-test --query agentPoolProfiles[0].count
```

3. **Deletion Test**

```bash
# Delete test resources
kubectl delete azureenvironment test-environment -n infra-test

# Verify cleanup
kubectl get managed -l environment=test
az resource list --tag environment=test
```

4. **Failure Recovery Test**

```bash
# Simulate resource deletion
az postgres flexible-server delete --name pg-test --resource-group rg-test --yes

# Watch Crossplane recreate
kubectl get managed | grep postgres
kubectl describe flexibleserver pg-test
```

#### Week 12: Production Cutover

**Cutover Checklist**:

- [ ] All resources migrated to Crossplane
- [ ] End-to-end tests passing
- [ ] Monitoring and alerting configured
- [ ] Documentation updated
- [ ] Team training completed
- [ ] Rollback plan ready
- [ ] Stakeholder approval obtained

**Cutover Steps**:

1. **Pre-Cutover**

```bash
# Freeze Pulumi changes
git tag pulumi-final-state

# Export final Pulumi state
pulumi stack export --file pulumi-final-export.json

# Create comprehensive backup
./scripts/backup-all-resources.sh
```

2. **Cutover**

```bash
# Switch CI/CD to use Crossplane
# Update ArgoCD/Flux to watch claims directory

# Verify GitOps sync
kubectl get applications -n argocd
argocd app list

# Monitor resource reconciliation
kubectl get managed -w
```

3. **Post-Cutover**

```bash
# Verify all resources managed by Crossplane
kubectl get managed | wc -l

# Check for drift
kubectl describe managed | grep "Last Reconcile"

# Decommission Pulumi
pulumi logout
```

---

## Testing & Validation

### Unit Testing Compositions

```yaml
# tests/unit/network-composition-test.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestSuite
testDirs:
  - tests/unit/network
---
# tests/unit/network/00-install.yaml
apiVersion: platform.example.com/v1alpha1
kind: AzureNetwork
metadata:
  name: test-network
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-test
    vnetName: vnet-test
    addressSpace:
      - "10.0.0.0/16"
    subnets:
      - name: snet-test
        addressPrefix: "10.0.0.0/24"
---
# tests/unit/network/00-assert.yaml
apiVersion: platform.example.com/v1alpha1
kind: AzureNetwork
metadata:
  name: test-network
status:
  conditions:
    - type: Ready
      status: "True"
```

### Integration Testing

```bash
# Run integration tests
kubectl kuttl test --config tests/kuttl-config.yaml

# Manual validation
./scripts/validate-resources.sh
```

### Validation Script

```bash
#!/bin/bash
# scripts/validate-resources.sh

echo "Validating Crossplane resources..."

# Check all managed resources are ready
NOT_READY=$(kubectl get managed -A -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True"))] | length')

if [ "$NOT_READY" -gt 0 ]; then
  echo "❌ $NOT_READY resources are not ready"
  kubectl get managed -A -o json | jq '.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True")) | .metadata.name'
  exit 1
else
  echo "✅ All managed resources are ready"
fi

# Check Azure resources exist
echo "Validating Azure resources..."
MISSING_RESOURCES=0

while read -r resource; do
  RESOURCE_TYPE=$(echo "$resource" | jq -r '.kind')
  RESOURCE_NAME=$(echo "$resource" | jq -r '.metadata.annotations."crossplane.io/external-name"')
  RESOURCE_GROUP=$(echo "$resource" | jq -r '.spec.forProvider.resourceGroupName')
  
  case "$RESOURCE_TYPE" in
    "VirtualNetwork")
      az network vnet show --name "$RESOURCE_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null || ((MISSING_RESOURCES++))
      ;;
    "StorageAccount")
      az storage account show --name "$RESOURCE_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null || ((MISSING_RESOURCES++))
      ;;
  esac
done < <(kubectl get managed -A -o json | jq -c '.items[]')

if [ "$MISSING_RESOURCES" -gt 0 ]; then
  echo "❌ $MISSING_RESOURCES Azure resources not found"
  exit 1
else
  echo "✅ All Azure resources validated"
fi

echo "✅ Validation complete!"
```

---

## Best Practices

### 1. Composition Design

**DO**:
- Create small, focused compositions
- Use composition functions for complex logic
- Version your XRDs (v1alpha1, v1beta1, v1)
- Document composition parameters
- Provide sensible defaults

**DON'T**:
- Create monolithic compositions
- Hard-code values
- Skip validation rules
- Forget to add labels and tags

### 2. Secret Management

**Use External Secrets Operator**:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: azure-credentials
  namespace: crossplane-system
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: azure-credentials
    creationPolicy: Owner
  data:
    - secretKey: credentials
      remoteRef:
        key: crossplane-azure-creds
```

### 3. RBAC Configuration

```yaml
# Namespace-level access for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: claim-creator
  namespace: infra-dev
rules:
  - apiGroups: ["platform.example.com"]
    resources: ["*"]
    verbs: ["get", "list", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers-claim-creator
  namespace: infra-dev
subjects:
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: claim-creator
  apiGroup: rbac.authorization.k8s.io
```

### 4. GitOps Integration

**ArgoCD Application**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infra-prod
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://github.com/example/crossplane-infra
    targetRevision: main
    path: claims/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: infra-prod
  syncPolicy:
    automated:
      prune: false  # Don't auto-delete resources
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 5. Monitoring & Alerting

**Prometheus Rules**:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: crossplane-alerts
  namespace: crossplane-system
spec:
  groups:
    - name: crossplane
      interval: 30s
      rules:
        - alert: ManagedResourceNotReady
          expr: crossplane_managed_resource_ready{condition="False"} > 0
          for: 10m
          annotations:
            summary: "Crossplane managed resource not ready"
            description: "{{ $labels.name }} in {{ $labels.namespace }} has been not ready for 10 minutes"
        
        - alert: ProviderUnhealthy
          expr: crossplane_provider_healthy{condition="False"} > 0
          for: 5m
          annotations:
            summary: "Crossplane provider unhealthy"
            description: "Provider {{ $labels.name }} has been unhealthy for 5 minutes"
```

### 6. Resource Naming Conventions

**Use Composition Functions for Naming**:

```yaml
# Use function-auto-ready or custom naming function
- step: generate-names
  functionRef:
    name: function-naming-convention
  input:
    apiVersion: naming.fn.crossplane.io/v1beta1
    kind: NamingConvention
    spec:
      pattern: "${projectName}-${environment}-${resourceType}-${sequence}"
      resourceType: storage-account
      maxLength: 24
      allowedCharacters: "a-z0-9"
```

### 7. Cost Management

**Tag Resources for Cost Tracking**:

```yaml
# Add cost tags to all compositions
commonPatches:
  - type: FromCompositeFieldPath
    fromFieldPath: spec.parameters.tags
    toFieldPath: spec.forProvider.tags
    policy:
      mergeOptions:
        appendSlice: false
        keepMapValues: true
  - type: ToCompositeFieldPath
    fromFieldPath: spec.forProvider.tags
    toFieldPath: status.appliedTags
    transforms:
      - type: map
        map:
          costCenter: "{{ .spec.parameters.costCenter }}"
          environment: "{{ .spec.parameters.environment }}"
          managedBy: "crossplane"
```

### 8. Backup & Disaster Recovery

**Velero Backup**:

```bash
# Backup Crossplane resources
velero backup create crossplane-backup \
  --include-namespaces crossplane-system,infra-prod,infra-staging,infra-dev \
  --include-resources compositeresourcedefinitions,compositions,providerconfigs

# Schedule regular backups
velero schedule create crossplane-daily \
  --schedule="0 2 * * *" \
  --include-namespaces crossplane-system,infra-prod,infra-staging,infra-dev
```

---

## Rollback Strategy

### Rollback Scenarios

#### Scenario 1: Composition Issue

```bash
# Revert to previous composition version
kubectl apply -f manifests/compositions/network/composition-network-v1.yaml

# Update claims to use old composition
kubectl patch azurenetwork prod-network -n infra-prod \
  --type merge \
  --patch '{"spec":{"compositionRef":{"name":"azure-network-v1"}}}'
```

#### Scenario 2: Provider Issue

```bash
# Rollback provider version
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v0.41.0
EOF

# Wait for provider ready
kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-azure-network
```

#### Scenario 3: Complete Rollback to Pulumi

```bash
# 1. Annotate Crossplane resources as external
kubectl annotate managed --all crossplane.io/management-policy=ObserveOnly

# 2. Re-import resources to Pulumi
pulumi import azure-native:network:VirtualNetwork vnet-prod /subscriptions/.../vnet-prod

# 3. Verify Pulumi state
pulumi stack export

# 4. Remove Crossplane resources (observe-only, won't delete Azure resources)
kubectl delete xr --all
```

---

## FAQs & Troubleshooting

### Q: How do I debug a resource that won't become ready?

```bash
# Check resource status
kubectl describe <resource-type> <resource-name>

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-azure-network

# Check Crossplane controller logs
kubectl logs -n crossplane-system deployment/crossplane

# Enable verbose logging
kubectl set env deployment/crossplane -n crossplane-system ARGS="--debug"
```

### Q: How do I import existing Azure resources?

```yaml
# Use external-name annotation and observe-only management
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: existing-vnet
  annotations:
    crossplane.io/external-name: vnet-existing
spec:
  managementPolicies: ["ObserveOnly"]
  forProvider:
    resourceGroupName: rg-existing
    location: northeurope
```

### Q: How do I handle resource dependencies?

```yaml
# Use selector or explicit references
spec:
  forProvider:
    # Option 1: Selector (dynamic reference)
    resourceGroupNameSelector:
      matchControllerRef: true
    
    # Option 2: Explicit reference
    virtualNetworkNameRef:
      name: my-vnet
    
    # Option 3: External reference (existing resource)
    subnetId: /subscriptions/.../subnets/existing-subnet
```

### Q: How do I update a live resource?

```bash
# Update claim
kubectl edit akscluster prod-aks -n infra-prod

# Or patch specific field
kubectl patch akscluster prod-aks -n infra-prod \
  --type merge \
  --patch '{"spec":{"parameters":{"kubernetesVersion":"1.29"}}}'

# Watch reconciliation
kubectl get managed -w
```

### Q: How do I handle secret rotation?

```yaml
# Use External Secrets Operator with auto-refresh
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-credentials
spec:
  refreshInterval: 1h  # Refresh every hour
  secretStoreRef:
    name: azure-keyvault
    kind: SecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: postgres-admin-password
```

### Q: Can I use Pulumi and Crossplane together?

Yes, during migration:

```yaml
# In Crossplane, mark Pulumi-managed resources as external
apiVersion: network.azure.upbound.io/v1beta1
kind: VirtualNetwork
metadata:
  name: pulumi-managed-vnet
  annotations:
    crossplane.io/external-name: vnet-from-pulumi
spec:
  managementPolicies: ["ObserveOnly"]
  # ... rest of spec
```

### Common Issues

#### Issue: Provider stays in "Installing" state

```bash
# Check provider pod
kubectl get pods -n crossplane-system | grep provider

# Check events
kubectl get events -n crossplane-system --sort-by='.lastTimestamp'

# Delete and reinstall
kubectl delete provider provider-azure-network
kubectl apply -f manifests/providers/provider-azure-network.yaml
```

#### Issue: Authentication failures

```bash
# Verify secret exists
kubectl get secret azure-credentials -n crossplane-system

# Check secret content
kubectl get secret azure-credentials -n crossplane-system -o jsonpath='{.data.credentials}' | base64 -d | jq

# Test credentials manually
az login --service-principal \
  -u $AZURE_CLIENT_ID \
  -p $AZURE_CLIENT_SECRET \
  --tenant $AZURE_TENANT_ID
```

#### Issue: Resources stuck in deleting

```bash
# Check finalizers
kubectl get <resource-type> <resource-name> -o yaml | grep finalizers -A 5

# Force remove finalizer (last resort)
kubectl patch <resource-type> <resource-name> \
  --type json \
  --patch='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

---

## Docker & Containerization

### Crossplane Operator Container

Unlike Pulumi's CLI-based execution model, Crossplane runs as Kubernetes operators. However, you can containerize your tooling for consistency.

#### Crossplane CLI Container

```dockerfile
# Dockerfile.crossplane-cli
FROM ubuntu:noble

ARG CROSSPLANE_VERSION=v1.14.0
ARG KUBECTL_VERSION=v1.28.0
ARG HELM_VERSION=v3.13.0
ARG YQ_VERSION=v4.35.1

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && chmod +x kubectl \
    && mv kubectl /usr/local/bin/

# Install Helm
RUN curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -xz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64

# Install Crossplane CLI
RUN curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh \
    && mv crossplane /usr/local/bin/

# Install yq
RUN curl -L "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]
```

#### Build and Use

```bash
# Build the image
docker build -f Dockerfile.crossplane-cli -t crossplane-cli:latest .

# Use for Crossplane operations
docker run -it --rm \
  -v ~/.kube:/root/.kube:ro \
  -v $(pwd):/workspace \
  crossplane-cli:latest

# Inside container
kubectl crossplane install configuration ...
```

### Composition Validator Container

```dockerfile
# Dockerfile.validator
FROM ubuntu:noble

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install kubectl and crossplane CLI
COPY --from=bitnami/kubectl:latest /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/
RUN curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh \
    && mv crossplane /usr/local/bin/

# Install validation tools
RUN pip3 install --no-cache-dir \
    pyyaml \
    jsonschema \
    openapi-spec-validator

COPY scripts/validate-compositions.sh /usr/local/bin/validate

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/validate"]
```

### Multi-Stage Build for Crossplane Functions

If you're building Composition Functions in Go:

```dockerfile
# Dockerfile.function
FROM golang:1.21-alpine AS builder

WORKDIR /workspace

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o function ./main.go

FROM gcr.io/distroless/static:nonroot

COPY --from=builder /workspace/function /function

USER 65532:65532

ENTRYPOINT ["/function"]
```

---

## GitHub Provider & Automation

### Why GitHub Provider?

The Crossplane GitHub provider enables:
- **Repository Management**: Create/manage repos as Kubernetes resources
- **Workflow Automation**: Define GitHub Actions workflows declaratively
- **Team Management**: Manage teams and permissions
- **Branch Protection**: Enforce branch policies as code
- **Secrets Management**: Sync GitHub secrets from Azure Key Vault

### Installing GitHub Provider

```yaml
# manifests/providers/provider-github.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-github
spec:
  package: xpkg.upbound.io/upbound/provider-github:v0.7.0
  packagePullPolicy: IfNotPresent
```

### Configure GitHub Provider

```bash
# Create GitHub personal access token secret
kubectl create secret generic github-credentials \
  -n crossplane-system \
  --from-literal=credentials="$(cat <<EOF
{
  "token": "${GITHUB_TOKEN}"
}
EOF
)"

# Apply ProviderConfig
kubectl apply -f - <<EOF
apiVersion: github.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      name: github-credentials
      namespace: crossplane-system
      key: credentials
EOF
```

### GitHub Repository Composition

```yaml
# manifests/compositions/github/xrd-github-repo.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xgithubrepos.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XGitHubRepo
    plural: xgithubrepos
  claimNames:
    kind: GitHubRepo
    plural: githubrepos
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
                    name:
                      type: string
                    description:
                      type: string
                    visibility:
                      type: string
                      enum: ["public", "private", "internal"]
                      default: "private"
                    hasIssues:
                      type: boolean
                      default: true
                    hasProjects:
                      type: boolean
                      default: true
                    hasWiki:
                      type: boolean
                      default: false
                    autoInit:
                      type: boolean
                      default: true
                    branchProtection:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                        requiredReviews:
                          type: integer
                        enforceAdmins:
                          type: boolean
                  required:
                    - name
              required:
                - parameters
```

```yaml
# manifests/compositions/github/composition-github-repo.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: github-repository
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XGitHubRepo
  
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          # GitHub Repository
          - name: repository
            base:
              apiVersion: repo.github.upbound.io/v1alpha1
              kind: Repository
              spec:
                forProvider:
                  visibility: private
                  hasIssues: true
                  hasProjects: true
                  hasWiki: false
                  autoInit: true
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.name
                toFieldPath: metadata.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.name
                toFieldPath: spec.forProvider.name
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.description
                toFieldPath: spec.forProvider.description
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.visibility
                toFieldPath: spec.forProvider.visibility
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.hasIssues
                toFieldPath: spec.forProvider.hasIssues
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.hasProjects
                toFieldPath: spec.forProvider.hasProjects
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.hasWiki
                toFieldPath: spec.forProvider.hasWiki
          
          # Branch Protection
          - name: branch-protection
            base:
              apiVersion: repo.github.upbound.io/v1alpha1
              kind: BranchProtection
              spec:
                forProvider:
                  repositoryIdSelector:
                    matchControllerRef: true
                  pattern: main
                  enforceAdmins: true
                  requiredPullRequestReviews:
                    - dismissStaleReviews: true
                      requireCodeOwnerReviews: true
                      requiredApprovingReviewCount: 1
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.branchProtection.enabled
                toFieldPath: spec.forProvider.enforceAdmins
              - type: FromCompositeFieldPath
                fromFieldPath: spec.parameters.branchProtection.requiredReviews
                toFieldPath: spec.forProvider.requiredPullRequestReviews[0].requiredApprovingReviewCount
```

### Use Case: Create Crossplane Infrastructure Repo

```yaml
# claims/management/crossplane-infra-repo-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: GitHubRepo
metadata:
  name: crossplane-azure-infrastructure
  namespace: management
spec:
  parameters:
    name: crossplane-azure-infrastructure
    description: "Crossplane compositions for Azure infrastructure"
    visibility: private
    hasIssues: true
    hasProjects: true
    hasWiki: false
    autoInit: true
    branchProtection:
      enabled: true
      requiredReviews: 2
      enforceAdmins: true
```

---

## CI/CD Workflows for Crossplane

### GitHub Actions for Crossplane

#### 1. Validate and Lint Compositions

```yaml
# .github/workflows/validate-crossplane.yaml
name: Validate Crossplane Compositions

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Install kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.28.0'
      
      - name: Install Crossplane CLI
        run: |
          curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
          sudo mv crossplane /usr/local/bin/
      
      - name: Install yq
        run: |
          sudo wget -qO /usr/local/bin/yq \
            https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
          sudo chmod +x /usr/local/bin/yq
      
      - name: Validate XRDs
        run: |
          for xrd in manifests/compositions/**/xrd-*.yaml; do
            echo "Validating $xrd"
            kubectl apply --dry-run=client -f "$xrd"
          done
      
      - name: Validate Compositions
        run: |
          for comp in manifests/compositions/**/composition-*.yaml; do
            echo "Validating $comp"
            kubectl apply --dry-run=client -f "$comp"
          done
      
      - name: Lint YAML
        uses: ibiqlik/action-yamllint@v3
        with:
          file_or_dir: manifests/
          config_data: |
            extends: default
            rules:
              line-length:
                max: 120
                level: warning
              indentation:
                spaces: 2
      
      - name: Check Composition Schema
        run: |
          ./scripts/validate-compositions.sh
```

#### 2. Build and Push Crossplane Configuration

```yaml
# .github/workflows/build-configuration.yaml
name: Build Crossplane Configuration Package

on:
  push:
    branches: [main]
    tags:
      - 'v*'
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/crossplane-config

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Crossplane CLI
        run: |
          curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
          sudo mv crossplane /usr/local/bin/
      
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha
      
      - name: Build Configuration Package
        run: |
          crossplane xpkg build \
            --package-root=. \
            --examples-root=./examples \
            --ignore=".git/*,.github/*,scripts/*,tests/*"
      
      - name: Push Configuration Package
        run: |
          crossplane xpkg push \
            --package crossplane.xpkg \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.tags }}
```

#### 3. Deploy to Environments

```yaml
# .github/workflows/deploy-crossplane.yaml
name: Deploy Crossplane Claims

on:
  push:
    branches: [main]
    paths:
      - 'claims/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod

jobs:
  deploy-dev:
    if: github.event_name == 'push' || github.event.inputs.environment == 'dev'
    runs-on: ubuntu-latest
    environment: dev
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Set AKS Context
        uses: azure/aks-set-context@v3
        with:
          resource-group: rg-crossplane-mgmt
          cluster-name: aks-crossplane-mgmt
      
      - name: Deploy to Dev
        run: |
          kubectl apply -f claims/dev/ -R
      
      - name: Wait for Resources
        run: |
          kubectl wait --for=condition=Ready \
            --all --all-namespaces \
            --timeout=600s \
            -l environment=dev
      
      - name: Verify Deployment
        run: |
          kubectl get managed -l environment=dev
          kubectl get compositeresourcedefinitions
          kubectl get compositions
  
  deploy-staging:
    if: github.event.inputs.environment == 'staging'
    runs-on: ubuntu-latest
    environment: staging
    needs: []
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Set AKS Context
        uses: azure/aks-set-context@v3
        with:
          resource-group: rg-crossplane-mgmt
          cluster-name: aks-crossplane-mgmt
      
      - name: Deploy to Staging
        run: |
          kubectl apply -f claims/staging/ -R
      
      - name: Run Integration Tests
        run: |
          ./scripts/integration-tests.sh staging
  
  deploy-prod:
    if: github.event.inputs.environment == 'prod'
    runs-on: ubuntu-latest
    environment: prod
    needs: []
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Set AKS Context
        uses: azure/aks-set-context@v3
        with:
          resource-group: rg-crossplane-mgmt
          cluster-name: aks-crossplane-mgmt
      
      - name: Create Backup
        run: |
          velero backup create pre-deploy-$(date +%Y%m%d-%H%M%S) \
            --include-namespaces infra-prod
      
      - name: Deploy to Production
        run: |
          kubectl apply -f claims/prod/ -R
      
      - name: Verify Production
        run: |
          ./scripts/verify-production.sh
```

#### 4. Generate Documentation

```yaml
# .github/workflows/generate-docs.yaml
name: Generate Crossplane Documentation

on:
  push:
    branches: [main]
    paths:
      - 'manifests/compositions/**'
      - 'docs/**'
  workflow_dispatch:

jobs:
  generate-docs:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install Dependencies
        run: |
          pip install pyyaml jinja2 markdown
      
      - name: Generate Composition Docs
        run: |
          python scripts/generate-composition-docs.py \
            --input manifests/compositions \
            --output docs/compositions
      
      - name: Generate Resource Reference
        run: |
          python scripts/generate-resource-reference.py \
            --input manifests/compositions \
            --output docs/reference.md
      
      - name: Build MkDocs
        run: |
          pip install mkdocs mkdocs-material
          mkdocs build
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        if: github.ref == 'refs/heads/main'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./site
```

### ArgoCD GitOps Workflow

```yaml
# .github/workflows/argocd-sync.yaml
name: ArgoCD Sync

on:
  push:
    branches: [main]
    paths:
      - 'claims/**'
      - 'manifests/**'

jobs:
  sync:
    runs-on: ubuntu-latest
    
    steps:
      - name: Install ArgoCD CLI
        run: |
          curl -sSL -o argocd-linux-amd64 \
            https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
          sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
      
      - name: Login to ArgoCD
        run: |
          argocd login ${{ secrets.ARGOCD_SERVER }} \
            --username admin \
            --password ${{ secrets.ARGOCD_PASSWORD }} \
            --insecure
      
      - name: Sync Applications
        run: |
          argocd app sync crossplane-compositions
          argocd app sync infra-dev
          argocd app wait crossplane-compositions --health
```

---

## Documentation Generation

### Auto-Generate Composition Documentation

Create a Python script to automatically generate documentation from your compositions:

```python
# scripts/generate-composition-docs.py
#!/usr/bin/env python3
"""
Generate Markdown documentation from Crossplane Compositions
"""

import yaml
import os
import sys
from pathlib import Path
from jinja2 import Template

TEMPLATE = """
# {{ composition_name }}

## Overview

**API Version**: `{{ api_version }}`  
**Kind**: `{{ kind }}`  
**Name**: `{{ name }}`

{{ description }}

## Labels

{% for key, value in labels.items() %}
- **{{ key }}**: {{ value }}
{% endfor %}

## Composite Resource Type

- **API Version**: {{ composite_type.apiVersion }}
- **Kind**: {{ composite_type.kind }}

## Resources Created

{% for resource in resources %}
### {{ loop.index }}. {{ resource.name }}

- **API Version**: `{{ resource.apiVersion }}`
- **Kind**: `{{ resource.kind }}`
- **Description**: {{ resource.description }}

{% if resource.patches %}
**Patches Applied**:
{% for patch in resource.patches %}
- {{ patch.type }}: `{{ patch.fromFieldPath }}` → `{{ patch.toFieldPath }}`
{% endfor %}
{% endif %}

{% endfor %}

## Usage Example

```yaml
apiVersion: {{ composite_type.apiVersion }}
kind: {{ composite_type.kind }}Claim
metadata:
  name: example-{{ name }}
  namespace: infra-dev
spec:
  parameters:
    # Add parameters here
```

## Related Resources

- [XRD Definition](xrd-{{ xrd_name }}.yaml)
- [Composition YAML](composition-{{ name }}.yaml)

---

*Auto-generated from composition manifest*
"""

def extract_composition_info(composition_file):
    """Extract information from a Composition YAML file"""
    with open(composition_file, 'r') as f:
        composition = yaml.safe_load(f)
    
    metadata = composition.get('metadata', {})
    spec = composition.get('spec', {})
    
    # Extract resources
    resources = []
    pipeline = spec.get('pipeline', [])
    for step in pipeline:
        input_data = step.get('input', {})
        for resource in input_data.get('resources', []):
            resources.append({
                'name': resource.get('name', 'unnamed'),
                'apiVersion': resource.get('base', {}).get('apiVersion', ''),
                'kind': resource.get('base', {}).get('kind', ''),
                'description': f"Manages {resource.get('base', {}).get('kind', 'resource')}",
                'patches': resource.get('patches', [])
            })
    
    return {
        'api_version': composition.get('apiVersion', ''),
        'kind': composition.get('kind', ''),
        'name': metadata.get('name', ''),
        'description': metadata.get('annotations', {}).get('description', 'No description provided'),
        'labels': metadata.get('labels', {}),
        'composite_type': spec.get('compositeTypeRef', {}),
        'resources': resources,
        'xrd_name': spec.get('compositeTypeRef', {}).get('kind', '').lower()
    }

def generate_docs(input_dir, output_dir):
    """Generate documentation for all compositions"""
    input_path = Path(input_dir)
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    template = Template(TEMPLATE)
    
    for composition_file in input_path.rglob('composition-*.yaml'):
        print(f"Processing {composition_file}")
        
        try:
            info = extract_composition_info(composition_file)
            composition_name = info['name']
            
            # Generate markdown
            markdown = template.render(**info, composition_name=composition_name)
            
            # Write to file
            output_file = output_path / f"{composition_name}.md"
            with open(output_file, 'w') as f:
                f.write(markdown)
            
            print(f"  → Generated {output_file}")
        
        except Exception as e:
            print(f"  ✗ Error processing {composition_file}: {e}")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate Crossplane Composition docs')
    parser.add_argument('--input', required=True, help='Input directory with compositions')
    parser.add_argument('--output', required=True, help='Output directory for docs')
    
    args = parser.parse_args()
    
    generate_docs(args.input, args.output)
    print("✓ Documentation generation complete!")
```

### MkDocs Configuration

```yaml
# mkdocs.yml
site_name: Crossplane Azure Infrastructure
site_description: Documentation for Crossplane-based Azure infrastructure
site_author: Infrastructure Team

theme:
  name: material
  palette:
    - scheme: default
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
    - scheme: slate
      primary: indigo
      accent: indigo
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - search.suggest
    - search.highlight
    - content.code.copy

nav:
  - Home: index.md
  - Getting Started:
      - Overview: getting-started/overview.md
      - Prerequisites: getting-started/prerequisites.md
      - Installation: getting-started/installation.md
  - Compositions:
      - Network: compositions/azure-network.md
      - AKS Cluster: compositions/aks-cluster.md
      - PostgreSQL: compositions/postgres.md
      - Storage: compositions/storage.md
      - Key Vault: compositions/keyvault.md
  - Developer Guide:
      - Creating Claims: developer-guide/creating-claims.md
      - Resource Parameters: developer-guide/parameters.md
      - Troubleshooting: developer-guide/troubleshooting.md
  - Operations:
      - Monitoring: operations/monitoring.md
      - Backup & Recovery: operations/backup.md
      - Upgrades: operations/upgrades.md
  - Reference:
      - Resource Mapping: reference/resource-mapping.md
      - API Reference: reference/api.md
  - Migration Guide: migration.md

plugins:
  - search
  - mermaid2

markdown_extensions:
  - pymdownx.highlight
  - pymdownx.superfences
  - pymdownx.tabbed
  - admonition
  - tables
  - toc:
      permalink: true
```

### Automated API Reference Generation

```python
# scripts/generate-resource-reference.py
#!/usr/bin/env python3
"""
Generate API reference from XRDs
"""

import yaml
from pathlib import Path

def generate_reference(input_dir, output_file):
    """Generate comprehensive API reference"""
    
    with open(output_file, 'w') as out:
        out.write("# Crossplane API Reference\n\n")
        out.write("This document provides detailed information about all Composite Resource Definitions (XRDs) and their parameters.\n\n")
        
        for xrd_file in Path(input_dir).rglob('xrd-*.yaml'):
            with open(xrd_file, 'r') as f:
                xrd = yaml.safe_load(f)
            
            metadata = xrd.get('metadata', {})
            spec = xrd.get('spec', {})
            
            out.write(f"## {spec.get('names', {}).get('kind', 'Unknown')}\n\n")
            out.write(f"**Group**: `{spec.get('group', '')}`\n\n")
            out.write(f"**Plural**: `{spec.get('names', {}).get('plural', '')}`\n\n")
            out.write(f"**Claim Name**: `{spec.get('claimNames', {}).get('kind', '')}`\n\n")
            
            # Extract parameters from schema
            for version in spec.get('versions', []):
                schema = version.get('schema', {}).get('openAPIV3Schema', {})
                parameters = schema.get('properties', {}).get('spec', {}).get('properties', {}).get('parameters', {})
                
                if parameters:
                    out.write("### Parameters\n\n")
                    out.write("| Parameter | Type | Required | Default | Description |\n")
                    out.write("|-----------|------|----------|---------|-------------|\n")
                    
                    for param_name, param_spec in parameters.get('properties', {}).items():
                        param_type = param_spec.get('type', 'string')
                        required = param_name in parameters.get('required', [])
                        default = param_spec.get('default', '-')
                        description = param_spec.get('description', '')
                        
                        out.write(f"| `{param_name}` | {param_type} | {'✓' if required else ''} | `{default}` | {description} |\n")
                    
                    out.write("\n")
            
            out.write("---\n\n")

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', required=True)
    parser.add_argument('--output', required=True)
    
    args = parser.parse_args()
    generate_reference(args.input, args.output)
    print(f"✓ API reference generated: {args.output}")
```

---

## Additional Resources

### Documentation
- [Crossplane Official Docs](https://docs.crossplane.io/)
- [Upbound Provider Azure](https://marketplace.upbound.io/providers/upbound/provider-azure)
- [Provider GitHub](https://marketplace.upbound.io/providers/upbound/provider-github)
- [Composition Functions](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Crossplane Configuration Packages](https://docs.crossplane.io/latest/concepts/packages/)

### Tools
- [crossplane CLI](https://docs.crossplane.io/latest/cli/)
- [crank](https://github.com/crossplane-contrib/crank) - Crossplane debugging tool
- [kubectl crossplane](https://docs.crossplane.io/latest/cli/command-reference/) - Kubectl plugin
- [yq](https://github.com/mikefarah/yq) - YAML processor for automation
- [MkDocs](https://www.mkdocs.org/) - Documentation site generator
- [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) - Material theme for MkDocs

### Community
- [Crossplane Slack](https://slack.crossplane.io/)
- [GitHub Discussions](https://github.com/crossplane/crossplane/discussions)
- [CNCF Crossplane](https://www.cncf.io/projects/crossplane/)

---

## Conclusion

This migration guide provides a comprehensive roadmap for migrating from Pulumi to Crossplane v2. The phased approach minimizes risk while enabling teams to adopt Kubernetes-native infrastructure management.

**Key Takeaways**:
1. Start small with pilot resources
2. Use compositions to abstract complexity
3. Leverage GitOps for deployment
4. Test thoroughly before production cutover
5. Keep Pulumi backup until fully validated

**Next Steps**:
1. Review this guide with your team
2. Set up Crossplane management cluster
3. Begin Phase 1 pilot migration
4. Iterate based on learnings
5. Scale to full production

Good luck with your migration!

---

**Document Version**: 1.0  
**Last Updated**: January 27, 2026  
**Maintained By**: Infrastructure Team  
**Contact**: infrastructure@example.com
