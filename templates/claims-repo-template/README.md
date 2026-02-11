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

## Support

If a claim does not become Ready:

- `kubectl describe <claimKind> <name> -n <team>`
- Ask the platform team to check XR and provider logs.
