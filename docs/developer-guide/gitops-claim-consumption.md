# Developer guide: GitOps-only claim consumption

This platform exposes self-service infrastructure through **Crossplane Claims**.
As an application team, you request infrastructure by committing claim YAML to Git.
**ArgoCD continuously syncs** those claims into the cluster and Crossplane reconciles the cloud resources.

This guide describes the recommended enterprise workflow:

- Developers create a dedicated **claims repo** from a golden template (GitHub “Use this template”).
- Developers fill in **repo name, app name, team, and environments**.
- Developers submit changes via PRs; ArgoCD applies them; Crossplane provisions/updates resources.

This repo includes a ready-to-use golden template under [templates/claims-repo-template/](../../templates/claims-repo-template/).
Platform teams typically copy that folder into a dedicated GitHub **template repository** (so developers can click “Use this template”).

---

## Mental model (who owns what)

- **Platform team owns**: providers, provider configs, XRDs, compositions, policies, ArgoCD bootstrap.
- **App/team owns**: claim instances (the desired infra requests) in their team namespace.

Reconciliation chain:

1. Git commit → ArgoCD detects change → applies claim to cluster
2. Crossplane sees claim → creates/updates XR + managed resources
3. Outputs appear in claim status and/or a connection Secret

---

## Recommended repo model

### Option A (recommended): one repo per app (template repo)

- Clear ownership and permissions
- Independent release cadence
- Easier audits and approvals

Example repo naming convention:

- `claims-<team>-<app>` (e.g., `claims-payments-checkout`)

### Option B: mono-repo per org

- Good when your org is small or wants one place to manage claims
- Can become noisy at scale unless you enforce strict folder ownership

---

## Golden template: required inputs

When a developer clicks **“Use this template”**, they must provide:

- **Repo name**: `claims-<team>-<app>`
- **Team**: Kubernetes namespace, e.g. `team-backend`
- **App name**: used for naming and tags, e.g. `backend`
- **Environments**: which of `dev`, `staging`, `prod` your app uses

The template should generate this structure:

```
.
├── claims/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── README.md
└── .github/
    └── CODEOWNERS
```

---

## Claim conventions (best practices)

### Namespaces

- Claims must be created in the team namespace.
- Use `metadata.namespace: <team>`.

### Naming

- Claim name should be stable and unique per environment.
- Recommended: `<env>-<app>-<capability>`
  - Example: `dev-backend-vnet`

### Composition selection

Prefer deterministic selection so changes don’t accidentally switch compositions:

- Use `spec.compositionSelector.matchLabels` for environment-specific variants, OR
- For production, consider `spec.compositionRef.name` (locked) if you want strict immutability.

### Minimal parameters

Claims should expose only a small, safe set of parameters.
Anything “platform-y” should be defaulted in the composition.

---

## Example claim (Network)

This platform exposes a **namespaced claim kind** (developer-facing) and uses the **XR kind** internally:

- Claim kind (what developers create): `VirtualNetwork`
- XR kind (internal implementation): `XVirtualNetwork`

Example (dev):

```yaml
apiVersion: azure.platform.io/v1alpha1
kind: VirtualNetwork
metadata:
  name: dev-backend-vnet
  namespace: team-backend
spec:
  parameters:
    location: eastus
  compositionSelector:
    matchLabels:
      provider: azure
      environment: dev
```

Notes:

- Platform team decides the exact `apiVersion`/`kind` and the allowed parameters.
- If a connection secret is emitted, it will be written into the same namespace.

---

## Day-2 workflow (how developers operate)

### Create or change infra

1. Change a claim YAML under `claims/<env>/...`
2. Open a PR
3. Get approvals (CODEOWNERS)
4. Merge
5. ArgoCD syncs, Crossplane reconciles

### Check status

- In cluster (kubectl):
  - `kubectl get <claimKind> -n <team>`
  - `kubectl describe <claimKind> <name> -n <team>`

- Using the provided Nushell helpers:
  - `source nu-scripts/crossplane.nu`
  - `xp claims -n team-backend`
  - `xp watch-claim dev-backend-vnet -n team-backend -k virtualnetwork`

### Consume outputs

Depending on how the platform was designed, outputs are typically delivered via:

- `status.atProvider` fields on managed resources (platform/internal)
- claim/XR status fields (developer-friendly)
- a Kubernetes Secret (connection details)

If a Secret is used:

- it should be in the same namespace as the claim
- it should have a predictable name (documented by the platform)

---

## Governance and safety (enterprise defaults)

- allowed regions
- allowed SKUs
- required tags
- quotas per team

Enforcement implementation in this repo:

- RBAC examples: [manifests/rbac/](../../manifests/rbac/)
- Kyverno policy examples: [policies/kyverno/](../../policies/kyverno/)

### Automatic policy attachment (Kyverno)

At enterprise scale, teams should not be manually “choosing policies”. Instead:

- Platform team manages **Kyverno** and the policy definitions.
- Teams get policies **automatically** based on **namespace labels**.
- The claims repo follows a **convention** so onboarding is consistent.

How it works:

1. A team namespace is created/labeled with a policy profile (for example `baseline`, `standard`, `restricted`).
2. Kyverno `ClusterPolicy` rules use `namespaceSelector.matchLabels` to apply the right guardrails.
3. Claims created inside that namespace inherit the guardrails automatically.

Recommended namespace labels (example):

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-backend
  labels:
    platform.io/team: team-backend
    platform.io/policy-profile: standard
    platform.io/environment: dev
```

Recommended Kyverno policy matching pattern (illustrative):

```yaml
match:
  resources:
    namespaceSelector:
      matchLabels:
        platform.io/policy-profile: standard
```

Repo convention (template repos):

- Include a single onboarding file like `bootstrap/tenant.yaml` that defines the desired namespace and access.
- The platform owns the onboarding API (Crossplane `Tenant` claim) and applies the namespace labels automatically.
- The template can still document expected labels, but onboarding automation should be the source of truth.

Policy exceptions:

- If a team needs a controlled one-off exception (temporary or app-specific), use Kyverno `PolicyException` resources owned/approved by the platform team.

---

## Troubleshooting checklist

If a claim doesn’t become Ready:

1. `kubectl describe <claimKind> <name> -n <team>`
2. Find the XR created by the claim (or ask platform team)
3. Check managed resources: `kubectl get managed`
4. Check provider logs (platform team): `xp logs-provider <provider>`

---

## What the template should include (platform team)

To make this workflow smooth, the claims template repo should include:

- a `README.md` explaining which claim kinds exist and examples per environment
- `CODEOWNERS` enforcing approvals
- optional CI for YAML/schema validation
- optional tooling (`make`, `nu`, or `task`) to generate a new claim file
