# Platform Rollback Guide

## Overview

The `platform-rollback.nu` script safely removes Crossplane platform resources in the correct order (reverse of deployment).

## 🎯 When to Use

- **Testing**: Clean up after platform testing
- **Migration**: Remove old platform before deploying new version
- **Troubleshooting**: Clean state when debugging issues
- **Environment cleanup**: Remove dev/test environments

## ⚠️ Safety Features

### 1. **Dry-Run Mode**

Always test first:

```bash
nu nu-scripts/platform-rollback.nu --environment dev --dry-run
```

### 2. **Active Claims Detection**

Prevents accidental deletion of platform when claims exist:

```bash
🔍 Checking for active claims...
  ⚠️  Found 5 active VirtualNetwork claims
❌ Active claims detected! Deleting platform resources will orphan these claims.
```

### 3. **Confirmation Prompt**

Requires typing "DELETE" to confirm:

```bash
⚠️  WARNING: This will delete all platform resources!
Type 'DELETE' to confirm:
```

### 4. **Backup Option**

Saves all resources before deletion:

```bash
nu nu-scripts/platform-rollback.nu --environment dev --backup
```

## 📋 Usage Examples

### Safe Rollback (Recommended)

```bash
# 1. Dry-run to see what would be deleted
nu nu-scripts/platform-rollback.nu --environment dev --dry-run

# 2. Backup before deletion
nu nu-scripts/platform-rollback.nu --environment dev --backup

# 3. Interactive rollback with confirmations
nu nu-scripts/platform-rollback.nu --environment dev
```

### Quick Rollback (Testing)

```bash
# Skip confirmations (use carefully!)
nu nu-scripts/platform-rollback.nu --environment dev --force
```

### Partial Rollback

```bash
# Rollback will ask if you want to delete providers
# Answer 'N' to keep providers installed
nu nu-scripts/platform-rollback.nu --environment dev
```

## 🔄 Deletion Order

The script removes resources in **reverse order** of deployment:

```
1. Compositions          (depends on XRDs)
2. XRDs                  (depends on nothing)
3. Functions             (independent)
4. Provider Configs      (depends on Providers)
5. Providers (optional)  (base layer)
```

## 🚨 Important Warnings

### ⚠️ Claims Must Be Deleted First

If you have active claims (user-created resources):

```bash
# 1. Delete all claims first
kubectl delete virtualnetwork --all -A
kubectl delete postgresqlinstance --all -A

# 2. Then run rollback
nu nu-scripts/platform-rollback.nu --environment dev
```

### ⚠️ Providers Delete CRDs

When you delete providers, all provider CRDs are removed. This includes:

- `VirtualNetwork` (from Azure network provider)
- `Subnet`, `SecurityGroup`, etc.

Only delete providers if you're doing a complete platform reset.

## 💾 Backup & Restore

### Create Backup

```bash
nu nu-scripts/platform-rollback.nu --environment dev --backup --dry-run
```

Saves to: `backups/platform-YYYYMMDD-HHMMSS/`

### Restore from Backup

```bash
# Apply backup files in order
kubectl apply -f backups/platform-20260129-143022/providers.yaml
kubectl apply -f backups/platform-20260129-143022/provider-configs.yaml
kubectl apply -f backups/platform-20260129-143022/functions.yaml
kubectl apply -f backups/platform-20260129-143022/xrds.yaml
kubectl apply -f backups/platform-20260129-143022/compositions.yaml
```

## 🔁 Rollback + Redeploy Workflow

### Clean Slate Redeployment

```bash
# 1. Backup current state
nu nu-scripts/platform-rollback.nu --environment dev --backup --dry-run

# 2. Dry-run rollback
nu nu-scripts/platform-rollback.nu --environment dev --dry-run

# 3. Execute rollback (keep providers)
nu nu-scripts/platform-rollback.nu --environment dev
# Answer 'N' when asked about providers

# 4. Redeploy platform
nu nu-scripts/platform-deploy.nu --environment dev --skip-providers
```

### Full Platform Reset

```bash
# 1. Complete rollback including providers
nu nu-scripts/platform-rollback.nu --environment dev --force

# 2. Full redeployment
nu nu-scripts/platform-deploy.nu --environment dev
```

## 📊 Troubleshooting

### Issue: "Active claims detected"

**Solution**: Delete all claims first

```bash
# List all claim types
kubectl get xrd -o jsonpath='{range .items[*]}{.spec.claimNames.kind}{"\n"}{end}'

# Delete claims of each type
kubectl delete <ClaimKind> --all -A
```

### Issue: Resources stuck in deletion

**Solution**: Remove finalizers

```bash
# Find stuck resources
kubectl get compositions -o json | jq '.items[] | select(.metadata.deletionTimestamp != null) | .metadata.name'

# Remove finalizers
kubectl patch composition <name> -p '{"metadata":{"finalizers":[]}}' --type=merge
```

### Issue: "Cannot delete provider configs"

**Solution**: Delete manually

```bash
kubectl get providerconfigs -A
kubectl delete providerconfig <name>
```

## 🎯 Best Practices

1. **Always dry-run first**: `--dry-run` flag
2. **Backup production**: `--backup` flag before production rollbacks
3. **Check claims**: Ensure no active claims exist
4. **Staged rollback**: Don't delete providers unless necessary
5. **Document reasons**: Note why you're rolling back
6. **Test recovery**: Practice backup/restore in dev

## 🔄 Comparison with Deployment

| Action         | Deployment                                            | Rollback                                              |
| -------------- | ----------------------------------------------------- | ----------------------------------------------------- |
| **Order**      | Providers → Configs → Functions → XRDs → Compositions | Compositions → XRDs → Functions → Configs → Providers |
| **Safety**     | Validates before applying                             | Checks claims, requires confirmation                  |
| **Dry-run**    | Validates syntax                                      | Shows what would be deleted                           |
| **Idempotent** | Yes (apply multiple times)                            | Yes (safe to run on clean cluster)                    |

## 💡 Tips

- Use `--dry-run` liberally
- Keep providers unless doing full reset
- Document backups with meaningful names
- Test rollback/redeploy flow in dev first
- Consider using GitOps for automatic recovery

## 📚 Related Commands

```bash
# Deploy platform
nu nu-scripts/platform-deploy.nu --environment dev

# Rollback platform
nu nu-scripts/platform-rollback.nu --environment dev

# Check what's installed
kubectl get providers,xrd,compositions,functions
```
