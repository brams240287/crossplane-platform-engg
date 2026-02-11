# ArgoCD Applications for Crossplane GitOps

This directory contains ArgoCD Application and ApplicationSet resources for managing Crossplane infrastructure as code.

## Architecture

### ApplicationSet Pattern (Recommended - Scalable)

We use **ApplicationSets** to automatically discover and manage platform components without manually creating individual Application resources.

#### Benefits:

- ✅ **Auto-discovery**: Automatically creates Applications for new environments/components
- ✅ **Scalability**: One ApplicationSet can manage dozens of Applications
- ✅ **DRY**: Define configuration once, apply to many
- ✅ **Consistency**: Same policies applied across all components
- ✅ **Reduced YAML**: No need to create Application per component

### ApplicationSets Available

#### 1. `crossplane-platform-appset.yaml`

Manages core platform components:

- **Providers** (prune: false - keep installed providers)
- **Compositions** (prune: true - remove deleted compositions)
- **Functions** (prune: true)
- **Provider Configs** (prune: false - keep credentials)

**Generator**: List-based - explicitly defined components

#### 2. `crossplane-claims-appset.yaml`

Manages infrastructure claims across environments:

- **Auto-discovers** all directories under `claims/` (dev, staging, prod)
- **Environment-aware**: Different policies per environment
- **Prod-safe**: Auto-prune disabled for production

**Generator**: Git directory discovery - automatically finds new environments

## Repository Structure Expected

```
.
├── manifests/
│   ├── providers/          # Managed by crossplane-platform-appset
│   ├── compositions/       # Managed by crossplane-platform-appset
│   ├── functions/          # Managed by crossplane-platform-appset
│   └── provider-configs/   # Managed by crossplane-platform-appset
└── claims/
    ├── dev/               # Auto-discovered by crossplane-claims-appset
    ├── staging/           # Auto-discovered by crossplane-claims-appset
    └── prod/              # Auto-discovered by crossplane-claims-appset
```

## How It Works

### Adding New Components

**Before (Manual)**:

```bash
# You had to create a new Application YAML for each component
# claims/team-a/dev/app.yaml -> new ArgoCD Application
# claims/team-b/dev/app.yaml -> new ArgoCD Application
# claims/team-a/staging/app.yaml -> new ArgoCD Application
```

**After (ApplicationSet)**:

```bash
# Just add the directory - ApplicationSet auto-discovers it!
mkdir -p claims/new-team/dev
# ApplicationSet automatically creates the Application
```

### Git Generator Discovery

The `crossplane-claims-appset` uses Git directory discovery:

1. Scans `claims/*` directories in your Git repo
2. Creates an Application for each discovered directory
3. Automatically detects environment (dev/staging/prod) from path
4. Applies appropriate sync policies per environment

### List Generator

The `crossplane-platform-appset` uses List generator for controlled management:

- Explicitly defines which platform components to manage
- Allows per-component configuration (prune policies, namespaces)
- More predictable for core platform components

## Installation

```bash
# Install ArgoCD first
./scripts/install-argocd.sh

# Apply ApplicationSets
kubectl apply -f config/argocd-applications/crossplane-platform-appset.yaml
kubectl apply -f config/argocd-applications/crossplane-claims-appset.yaml

# Check generated Applications
kubectl get applications -n argocd
```

## Sync Policies

| Component        | Auto-Sync | Self-Heal | Auto-Prune | Rationale                   |
| ---------------- | --------- | --------- | ---------- | --------------------------- |
| Providers        | ✅        | ✅        | ❌         | Never auto-delete providers |
| Compositions     | ✅        | ✅        | ✅         | Safe to recreate            |
| Functions        | ✅        | ✅        | ✅         | Safe to recreate            |
| Provider Configs | ✅        | ✅        | ❌         | Keep credentials            |
| Claims (Dev)     | ✅        | ✅        | ✅         | Fast iteration              |
| Claims (Staging) | ✅        | ✅        | ✅         | Pre-prod testing            |
| Claims (Prod)    | ✅        | ✅        | ❌         | Manual deletion approval    |

## Alternative Approaches

### 1. Individual Applications (Not Recommended)

❌ Doesn't scale  
❌ Lots of YAML duplication  
❌ Manual work for each new environment

See `crossplane-claims-dev.yaml` and similar files as examples.

### 2. App of Apps Pattern

✅ Single root Application  
⚠️ Still requires manually defining child Applications  
⚠️ Less flexible than ApplicationSet

### 3. Monorepo with Kustomize Overlays

✅ Good for template reuse  
⚠️ Still needs Applications per environment  
✅ Can combine with ApplicationSet

## Advanced: Matrix Generator

For even more power, you can combine multiple generators:

```yaml
generators:
  - matrix:
      generators:
        # Dimension 1: Environments
        - list:
            elements:
              - env: dev
                prune: "true"
              - env: prod
                prune: "false"
        # Dimension 2: Teams
        - list:
            elements:
              - team: backend
                namespace: team-backend
              - team: frontend
                namespace: team-frontend
# Creates: dev-backend, dev-frontend, prod-backend, prod-frontend
```

This creates a Cartesian product of Applications across all dimensions.

## Monitoring

```bash
# View all Applications generated by ApplicationSets
kubectl get applications -n argocd -l managed-by=argocd

# View ApplicationSets
kubectl get applicationsets -n argocd

# Check sync status
argocd app list
```

## Troubleshooting

### Applications not appearing

```bash
# Check ApplicationSet status
kubectl describe applicationset crossplane-claims -n argocd

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller
```

### Wrong Applications generated

- Verify directory structure matches expected pattern
- Check generator configuration
- Review template placeholders ({{.path.basename}}, etc.)

## References

- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- [ApplicationSet Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators/)
- [Crossplane GitOps Best Practices](https://docs.crossplane.io/latest/guides/crossplane-with-gitops/)
