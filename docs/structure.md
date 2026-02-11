# Crossplane Repository Structure

## 📁 Directory Overview

```
crossplane-infrastructure/
├── .github/workflows/          # CI/CD pipelines (GitHub Actions)
├── .gitignore                  # Git ignore patterns
├── README.md                   # Main repository documentation
├── migration.md                # Pulumi to Crossplane migration guide
├── mkdocs.yml                  # MkDocs configuration
│
├── manifests/                  # Crossplane manifests
│   ├── namespaces/            # Kubernetes namespaces
│   ├── providers/             # Crossplane provider installations
│   ├── provider-configs/      # Provider authentication configs
│   └── compositions/          # XRDs and Compositions
│       ├── network/           # Virtual Networks, Subnets, NSGs
│       ├── compute/           # Virtual Machines, Scale Sets
│       ├── kubernetes/        # AKS Clusters
│       ├── database/          # PostgreSQL, MySQL, CosmosDB
│       ├── storage/           # Storage Accounts, File Shares
│       ├── security/          # Key Vaults, Managed Identities
│       ├── application-gateway/ # App Gateway with WAF
│       ├── application-stack/ # High-level app infrastructure
│       ├── platform/          # Complete environments
│       └── github/            # GitHub repository automation
│
├── claims/                    # Resource claims by environment
│   ├── dev/
│   │   └── application-stacks/
│   ├── staging/
│   │   └── application-stacks/
│   └── prod/
│       └── application-stacks/
│
├── patches/                   # Kustomize patches
├── functions/                 # Composition functions
│   ├── naming-convention/    # Naming policy enforcement
│   ├── tagging/              # Auto-tagging resources
│   ├── resource-limiter/     # Resource quota enforcement
│   └── cost-calculator/      # Cost estimation
│
├── policies/                  # Governance policies (OPA/Kyverno)
│
├── scripts/                   # Automation scripts
│   ├── install-crossplane.sh
│   ├── install-providers.sh
│   └── validate-compositions.sh
│
├── tests/                     # Tests
│   ├── unit/                 # Unit tests
│   ├── integration/          # Integration tests
│   └── fixtures/             # Test data
│       ├── sample-claims/
│       └── test-data/
│
├── examples/                  # Sample configurations
│   ├── simple-vm/
│   ├── aks-with-networking/
│   ├── complete-environment/
│   └── application-stack-samples/
│
├── docs/                      # Documentation
│   ├── getting-started/
│   ├── developer-guide/
│   ├── operations-guide/
│   ├── compositions/         # Auto-generated
│   └── reference/
│
└── config/                    # GitOps configuration
    ├── argocd-applications/
    └── flux/
```

## 🚀 Quick Start

1. **Install Crossplane**
   ```bash
   ./scripts/install-crossplane.sh
   ```

2. **Install Providers**
   ```bash
   ./scripts/install-providers.sh
   ```

3. **Validate Compositions**
   ```bash
   ./scripts/validate-compositions.sh
   ```

## 📝 What's Included

### Core Files
- ✅ README.md - Comprehensive repository documentation
- ✅ .gitignore - Standard ignore patterns
- ✅ migration.md - Complete Pulumi → Crossplane migration guide
- ✅ mkdocs.yml - Documentation site configuration

### Scripts (Executable)
- ✅ install-crossplane.sh - Install Crossplane with Helm
- ✅ install-providers.sh - Install Azure providers
- ✅ validate-compositions.sh - Validate XRDs and compositions

### Documentation Structure
- ✅ docs/index.md - Documentation homepage
- ✅ Composition READMEs in each composition directory
- 📁 Structured docs for getting started, development, and operations

## 📦 Next Steps

1. **Add Provider Manifests**
   - Create provider YAML files in `manifests/providers/`
   - Configure authentication in `manifests/provider-configs/`

2. **Create Compositions**
   - Define XRDs in `manifests/compositions/*/xrd-*.yaml`
   - Create compositions in `manifests/compositions/*/composition-*.yaml`

3. **Add Claims**
   - Create resource claims in `claims/{env}/`
   - Add application stacks in `claims/{env}/application-stacks/`

4. **Set Up CI/CD**
   - Add GitHub Actions workflows in `.github/workflows/`
   - Configure ArgoCD applications in `config/argocd-applications/`

5. **Write Tests**
   - Add unit tests in `tests/unit/`
   - Add integration tests in `tests/integration/`

6. **Add Policies**
   - Create OPA policies in `policies/`
   - Define resource quotas and naming conventions

## 🔧 Development Workflow

1. Create/modify compositions in `manifests/compositions/`
2. Validate changes: `./scripts/validate-compositions.sh`
3. Test locally with claims
4. Commit and push (CI/CD will validate)
5. Deploy via GitOps (ArgoCD/Flux)

## 📚 Documentation

Run the documentation site locally:

```bash
pip install mkdocs mkdocs-material
mkdocs serve
```

Visit: http://localhost:8000

## 🎯 Key Features

✅ **Complete directory structure** for Crossplane platform engineering
✅ **Separation of concerns** (manifests, claims, functions, policies)
✅ **Multi-environment support** (dev, staging, prod)
✅ **Application Stack pattern** for high-level abstractions
✅ **GitOps ready** with ArgoCD/Flux configuration
✅ **Documentation site** with MkDocs Material theme
✅ **Automation scripts** for common operations
✅ **Test structure** for validation and integration testing

---

**Created:** January 27, 2026
**Structure Version:** 1.0
