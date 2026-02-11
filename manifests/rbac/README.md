# RBAC for Crossplane claims (team self-service)

Goal:

- Teams can create/update **namespaced claim kinds** (e.g., `VirtualNetwork`) in their own namespace.
- Teams cannot create **cluster-scoped XRs** (e.g., `XVirtualNetwork`) directly.

## Recommended approach

1. Prefer **claim kinds** (`spec.claimNames`) in XRDs.
   - Claim is **namespaced** → easy RBAC boundary.
   - XR stays **cluster-scoped** → created by Crossplane controllers, not humans.

2. Use **Role + RoleBinding per team namespace**.
   - Bind to an IdP group (OIDC) or a Kubernetes group that represents the team.
   - Avoid ClusterRole for write permissions.

3. Optionally add Kyverno as a safety net.
   - Deny direct creation/updates of XR kinds by non-platform identities.
   - Allow Crossplane service account to create XRs.

## Files

- `team-backend-virtualnetwork-claims.yaml`
  - Example Role/RoleBinding for the `team-backend` namespace.

## How to onboard a new team

- Copy `team-backend-virtualnetwork-claims.yaml` → rename namespace + group.
- Apply it (GitOps or `kubectl apply`).

> Note: RBAC cannot filter secrets by label, so keep secret access separate and tightly controlled.
