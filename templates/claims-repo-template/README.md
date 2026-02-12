# Crossplane Claims Repo (Template)

This repository is a **golden template** for application teams to request infrastructure from the platform using **Crossplane claims via GitOps**.

## How it works

- You create this repo using GitHub **“Use this template”**.
- You run a one-time bootstrap workflow that asks for:
  - Team namespace
  - App name
  - Environments (dev/staging/prod)
  - Policy profile (baseline/standard/restricted)
- The workflow creates a PR that:
  - writes `bootstrap/team.yaml`
  - writes `bootstrap/tenant.yaml` (self-service onboarding; provisions namespace + RBAC + labels)
  - creates/updates example claim files under `claims/<env>/`
  - sets `.github/CODEOWNERS`

After bootstrap:

- Developers change files under `claims/<env>/...`
- Open a PR → approvals → merge
- ArgoCD syncs → Crossplane reconciles

## Repo layout

```
.
├── bootstrap/
│   ├── team.yaml
│   └── tenant.yaml
├── claims/
│   ├── dev/
│   ├── staging/
│   └── prod/
└── .github/
    ├── CODEOWNERS
    └── workflows/
        ├── bootstrap.yml
        └── lint.yml
```

## What to edit

- Add/update claim YAMLs under `claims/<env>/`.
- The `bootstrap/tenant.yaml` is typically platform-owned; change it only when onboarding inputs change.
- Do **not** edit platform-managed compositions/providers in this repo.

## Discover available claim types

The commands in **Support** below are for troubleshooting a _specific claim instance_.

To discover what claim types are available in your cluster, use one of these approaches:

### Option 1 (recommended): use a platform “claim catalog”

In most orgs, app teams don’t get permission to list cluster-scoped Crossplane objects (like XRDs), so discovery is best done via a platform-owned catalog (docs page) that lists:

- Claim kind + API version (e.g., `VirtualNetwork.azure.platform.io/v1alpha1`)
- What it provisions
- Required/optional fields
- Example YAML

If your platform team provides a catalog, use that as the source of truth.

### Option 2: discover via Kubernetes API resources (works for many teams)

List namespaced resources in the claim API group (adjust the group to your platform):

- `kubectl api-resources --api-group=azure.platform.io --namespaced=true`

Then inspect the schema for a specific kind:

- `kubectl explain <claimKind> --api-version=azure.platform.io/v1alpha1`

### Option 3 (platform/admin): discover via Crossplane XRDs

If you have permission to view XRDs, claim types are “published” when an XRD has `spec.claimNames`:

- `kubectl get xrd`
- `kubectl get xrd <xrd-name> -o yaml | sed -n '/claimNames:/,/^[^ ]/p'`

## Support

If a claim does not become Ready:

- `kubectl describe <claimKind> <name> -n <team>`
- `kubectl get <claimKind> <name> -n <team> -o yaml`
- `kubectl describe <claimKind> <name> -n <team>`
- Ask the platform team to check XR and provider logs.
