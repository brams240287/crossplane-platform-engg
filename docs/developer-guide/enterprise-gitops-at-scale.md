# Enterprise GitOps at scale (multi-team claim repos)

This page describes patterns that work well when you have **many teams** and want a standard “Use this template” flow.

---

## Goal

- Each team/app has its own claims repo created from a golden template.
- The cluster automatically discovers those repos and continuously syncs claims.
- You can enforce approvals and guardrails consistently.

This model works best when teams create **namespaced claim kinds** (e.g., `VirtualNetwork`) rather than cluster-scoped XRs.
It enables clean RBAC boundaries per namespace and reduces accidental cross-team impact.

---

## Recommended pattern: ArgoCD ApplicationSet + repo discovery

Instead of manually creating one ArgoCD Application per repo, use an **ApplicationSet generator** that discovers repos.

Two common discovery strategies:

### 1) GitHub org repo discovery (recommended)

- Teams create repos from a template.
- The template applies a **GitHub topic** like `crossplane-claims`.
- ArgoCD ApplicationSet uses the **SCM Provider generator** to discover all repos in the org with that topic.

Benefits:

- Zero-touch onboarding: create repo → it gets picked up
- Standardization: consistent directory layout and policies

Operational notes:

- Prefer using a **GitHub App** over a long-lived PAT.
- Scope access to read-only if possible.

### 2) “Claims registry” repo (more controlled)

- Maintain a central repo containing a list of team claim repos.
- ApplicationSet reads that list and creates Applications.

Benefits:

- Explicit onboarding approvals
- Easier to reason about blast radius

---

## Directory contract (what ArgoCD expects)

For repo-discovery to work predictably, enforce a standard folder layout:

```
claims/
  dev/
  staging/
  prod/
```

- `claims/dev/**` and `claims/staging/**` can be auto-synced with prune enabled.
- `claims/prod/**` should typically require stricter approvals and often `prune: false`.

---

## Policy attachment (automatic): namespace labels + repo convention

To keep policy enforcement consistent across hundreds of repos, attach guardrails automatically using Kyverno:

- Platform team defines Kyverno `ClusterPolicy` rules.
- Policies apply based on **namespace labels** (via `namespaceSelector.matchLabels`).
- The repo template enforces a **convention** so every team supplies the same inputs.

Recommended label taxonomy:

- `platform.io/team`: owning team identifier
- `platform.io/environment`: `dev|staging|prod`
- `platform.io/policy-profile`: `baseline|standard|restricted`

At scale, prefer a single onboarding artifact such as `bootstrap/tenant.yaml` (a Crossplane `Tenant` claim) that provisions namespaces, RBAC, and labels automatically.

Repo convention options:

1. **Self-service namespaces (fast onboarding):** the template repo includes a `bootstrap/namespace.yaml` manifest with the required labels. ArgoCD creates/labels the namespace during the first sync.
2. **Platform-managed namespaces (most common):** onboarding automation creates the namespace and applies the labels. The template repo includes a short file documenting the required labels and expected policy profile per environment.

The important part is that teams do not edit policy definitions; they only pick (or inherit) a policy profile through the namespace.

---

## Governance (recommended defaults)

- Repo template includes:
  - `.github/CODEOWNERS` requiring approvals from the owning team
  - branch protection (required checks + reviews)
  - mandatory PRs for prod folder changes

- Kubernetes-level controls:
  - RBAC: team can only read/write claims in their namespace
  - policy: allowed regions/SKUs, required tags, quotas

---

## Suggested enterprise workflow

1. Developer clicks “Use this template” to create `claims-<team>-<app>`
2. Template action asks for:
   - Team namespace
   - App name
   - Environments
3. Repo is created with:
   - correct folders
   - example claim stubs
   - CODEOWNERS / policies
4. ArgoCD auto-discovers and begins syncing

---

## When to pick which model

- Repo discovery is best when:
  - you want fast onboarding
  - repos are consistently structured
  - you can manage GitHub App credentials securely

- Registry repo is best when:
  - you need explicit onboarding controls
  - you’re in a regulated environment
  - you want platform-team review before any repo is synced
