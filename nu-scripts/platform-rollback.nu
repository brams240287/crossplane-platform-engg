#!/usr/bin/env nu
# Crossplane Platform Rollback Script
# This script safely removes platform resources in reverse order
# Usage: nu nu-scripts/platform-rollback.nu [--environment dev|staging|prod] [--dry-run] [--force]

def main [
    --environment (-e): string = "dev"  # Target environment
    --dry-run (-d)                       # Show what would be deleted without actually deleting
    --force (-f)                         # Skip confirmation prompts (use with caution)
    --backup (-b)                        # Backup resources before deletion
    --gitops                             # Also remove ArgoCD GitOps objects (Applications/ApplicationSets)
] {
    print $"(ansi red_bold)⚠️  Crossplane Platform Rollback(ansi reset)"
    print $"Environment: ($environment)"
    print ""
    
    if $dry_run {
        print $"(ansi yellow)ℹ️  Running in DRY-RUN mode - no changes will be made(ansi reset)"
        print ""
    }
    
    # Safety check - validate prerequisites
    if not (check-prerequisites) {
        print $"(ansi red_bold)❌ Prerequisites not met(ansi reset)"
        exit 1
    }
    
    # Check for active claims
    let has_claims = (check-for-active-claims)
    if $has_claims and (not $force) {
        print $"(ansi red_bold)❌ Active claims detected! Deleting platform resources will orphan these claims.(ansi reset)"
        print $"(ansi yellow)To proceed anyway, use --force flag (NOT recommended)(ansi reset)"
        exit 1
    }
    
    # Backup if requested
    if $backup {
        print $"(ansi cyan_bold)💾 Backing up platform resources...(ansi reset)"
        backup-platform-resources
    }
    
    # Final confirmation
    if not $force and not $dry_run {
        print $"(ansi red_bold)⚠️  WARNING: This will delete all platform resources!(ansi reset)"
        print "Resources to be deleted:"
        print "  • Compositions"
        print "  • XRDs (Composite Resource Definitions)"
        print "  • Composition Functions"
        print "  • Provider Configurations"
        print "  • Providers (optional)"
        print ""
        
        let response = (input "Type 'DELETE' to confirm: ")
        if $response != "DELETE" {
            print $"(ansi yellow)Rollback cancelled(ansi reset)"
            exit 0
        }
    }
    
    # Optional: remove ArgoCD GitOps objects first
    if $gitops {
        print ""
        print $"(ansi cyan_bold)🧹 GitOps Step 0: Removing ArgoCD objects...(ansi reset)"
        if $dry_run {
            print "  DRY-RUN: would delete Crossplane Applications/ApplicationSets from config/argocd-applications"
        } else {
            # Delete in a safe order: generated apps will disappear after appsets are gone.
            if (ls config/argocd-applications/crossplane-platform-appset.yaml | is-empty) == false {
                kubectl delete -f config/argocd-applications/crossplane-platform-appset.yaml 2>/dev/null | ignore
            }
            if (ls config/argocd-applications/crossplane-bootstrap-appset.yaml | is-empty) == false {
                kubectl delete -f config/argocd-applications/crossplane-bootstrap-appset.yaml 2>/dev/null | ignore
            }
            if (ls config/argocd-applications/crossplane-claims-appset.yaml | is-empty) == false {
                kubectl delete -f config/argocd-applications/crossplane-claims-appset.yaml 2>/dev/null | ignore
            }
            if (ls config/argocd-applications/crossplane-providers.yaml | is-empty) == false {
                kubectl delete -f config/argocd-applications/crossplane-providers.yaml 2>/dev/null | ignore
            }
            print $"  (ansi green)✓ Requested deletion of ArgoCD GitOps objects(ansi reset)"
        }
    }

    # Rollback in reverse order (opposite of deployment)
    print ""
    print $"(ansi cyan_bold)🔄 Starting rollback process...(ansi reset)"
    print ""
    
    # Step 1: Delete Compositions
    print $"(ansi cyan_bold)🎨 Step 1: Removing Compositions...(ansi reset)"
    if $dry_run {
        delete-compositions $environment --dry-run
    } else {
        delete-compositions $environment
    }
    
    # Step 2: Delete XRDs
    print $"(ansi cyan_bold)📋 Step 2: Removing XRDs...(ansi reset)"
    if $dry_run {
        delete-xrds --dry-run
    } else {
        delete-xrds
    }
    
    # Step 3: Delete Functions
    print $"(ansi cyan_bold)⚡ Step 3: Removing Functions...(ansi reset)"
    if $dry_run {
        delete-functions --dry-run
    } else {
        delete-functions
    }
    
    # Step 4: Delete Provider Configs
    print $"(ansi cyan_bold)🔧 Step 4: Removing Provider Configurations...(ansi reset)"
    if $dry_run {
        delete-provider-configs --dry-run
    } else {
        delete-provider-configs
    }
    
    # Step 5: Delete Providers (optional, with confirmation)
    if not $force and not $dry_run {
        let delete_providers = (input "Do you want to delete providers as well? (y/N): ")
        if $delete_providers == "y" or $delete_providers == "Y" {
            print $"(ansi cyan_bold)📦 Step 5: Removing Providers...(ansi reset)"
            delete-providers
        } else {
            print $"(ansi yellow)⏭️  Skipping provider deletion(ansi reset)"
        }
    } else if $force {
        print $"(ansi cyan_bold)📦 Step 5: Removing Providers...(ansi reset)"
        if $dry_run {
            delete-providers --dry-run
        } else {
            delete-providers
        }
    }
    
    print ""
    if $dry_run {
        print $"(ansi green_bold)✅ Dry-run complete - no changes were made(ansi reset)"
    } else {
        print $"(ansi green_bold)✅ Rollback complete!(ansi reset)"
    }
    
    print ""
    print $"(ansi cyan)💡 To redeploy: nu nu-scripts/platform-deploy.nu --environment ($environment)(ansi reset)"
}

# Check prerequisites
def check-prerequisites [] {
    print "Checking prerequisites..."
    
    # Check kubectl
    if (which kubectl | is-empty) {
        print $"(ansi red)❌ kubectl not found(ansi reset)"
        return false
    }
    
    # Check cluster connectivity
    try {
        kubectl cluster-info | ignore
        print $"(ansi green)✅ Cluster accessible(ansi reset)"
    } catch {
        print $"(ansi red)❌ Cannot connect to cluster(ansi reset)"
        return false
    }
    
    true
}

# Check for active claims (user-created resources)
def check-for-active-claims [] {
    print "🔍 Checking for active claims..."
    
    try {
        # Get all XRDs to find claim kinds
        let xrds = (kubectl get xrd -o json | from json | get items)
        
        for xrd in $xrds {
            let claim_kind = ($xrd.spec?.claimNames?.kind? | default "")
            if $claim_kind != "" {
                # Check if any claims of this type exist
                # Try namespaced list first; fall back to cluster-scoped list.
                let claims_all = (kubectl get $claim_kind -A --no-headers 2>/dev/null | complete)
                let claims = if $claims_all.exit_code == 0 {
                    $claims_all
                } else {
                    (kubectl get $claim_kind --no-headers 2>/dev/null | complete)
                }

                if $claims.exit_code == 0 and ($claims.stdout | str length) > 0 {
                    let claim_count = ($claims.stdout | lines | length)
                    print $"  (ansi yellow)⚠️  Found ($claim_count) active ($claim_kind) claims(ansi reset)"
                    return true
                }
            }
        }
        
        print $"  (ansi green)✓ No active claims found(ansi reset)"
        false
    } catch {
        print $"  (ansi yellow)⚠️  Could not check for claims(ansi reset)"
        false
    }
}

# Backup platform resources
def backup-platform-resources [] {
    let timestamp = (date now | format date "%Y%m%d-%H%M%S")
    let backup_dir = $"backups/platform-($timestamp)"
    
    mkdir $backup_dir
    
    print $"  Creating backup in ($backup_dir)..."
    
    # Backup providers
    try {
        kubectl get providers -o yaml | save $"($backup_dir)/providers.yaml"
        print $"    ✓ Providers backed up"
    } catch {}
    
    # Backup provider configs
    try {
        kubectl get providerconfigs -A -o yaml | save $"($backup_dir)/provider-configs.yaml"
        print $"    ✓ Provider configs backed up"
    } catch {}
    
    # Backup functions
    try {
        kubectl get functions -o yaml | save $"($backup_dir)/functions.yaml"
        print $"    ✓ Functions backed up"
    } catch {}
    
    # Backup XRDs
    try {
        kubectl get xrd -o yaml | save $"($backup_dir)/xrds.yaml"
        print $"    ✓ XRDs backed up"
    } catch {}
    
    # Backup compositions
    try {
        kubectl get compositions -o yaml | save $"($backup_dir)/compositions.yaml"
        print $"    ✓ Compositions backed up"
    } catch {}
    
    print $"  (ansi green)✅ Backup saved to ($backup_dir)(ansi reset)"
}

# Delete compositions
def delete-compositions [environment: string, --dry-run] {
    try {
        let compositions = (kubectl get compositions --no-headers -o custom-columns=":metadata.name" | lines)
        
        if ($compositions | is-empty) {
            print $"  (ansi yellow)ℹ️  No compositions found(ansi reset)"
            return
        }
        
        print $"  Found ($compositions | length) compositions"
        
        for comp in $compositions {
            print $"    🗑️  Deleting ($comp)..."
            if $dry_run {
                print $"      (ansi yellow)DRY-RUN: Would delete composition ($comp)(ansi reset)"
            } else {
                kubectl delete composition $comp --timeout=30s
                print $"      (ansi green)✓ Deleted(ansi reset)"
            }
        }
    } catch {
        print $"  (ansi yellow)⚠️  No compositions to delete or error occurred(ansi reset)"
    }
}

# Delete XRDs
def delete-xrds [--dry-run] {
    try {
        let xrds = (kubectl get xrd --no-headers -o custom-columns=":metadata.name" | lines)
        
        if ($xrds | is-empty) {
            print $"  (ansi yellow)ℹ️  No XRDs found(ansi reset)"
            return
        }
        
        print $"  Found ($xrds | length) XRDs"
        
        for xrd in $xrds {
            print $"    🗑️  Deleting ($xrd)..."
            if $dry_run {
                print $"      (ansi yellow)DRY-RUN: Would delete XRD ($xrd)(ansi reset)"
            } else {
                kubectl delete xrd $xrd --timeout=30s
                print $"      (ansi green)✓ Deleted(ansi reset)"
            }
        }
    } catch {
        print $"  (ansi yellow)⚠️  No XRDs to delete or error occurred(ansi reset)"
    }
}

# Delete functions
def delete-functions [--dry-run] {
    try {
        let functions = (kubectl get functions --no-headers -o custom-columns=":metadata.name" | lines)
        
        if ($functions | is-empty) {
            print $"  (ansi yellow)ℹ️  No functions found(ansi reset)"
            return
        }
        
        print $"  Found ($functions | length) functions"
        
        for func in $functions {
            print $"    🗑️  Deleting ($func)..."
            if $dry_run {
                print $"      (ansi yellow)DRY-RUN: Would delete function ($func)(ansi reset)"
            } else {
                kubectl delete function $func --timeout=30s
                print $"      (ansi green)✓ Deleted(ansi reset)"
            }
        }
    } catch {
        print $"  (ansi yellow)⚠️  No functions to delete or error occurred(ansi reset)"
    }
}

# Delete provider configs
def delete-provider-configs [--dry-run] {
    try {
        let configs = (kubectl get providerconfigs -A --no-headers -o custom-columns=":metadata.name" | lines)
        
        if ($configs | is-empty) {
            print $"  (ansi yellow)ℹ️  No provider configs found(ansi reset)"
            return
        }
        
        print $"  Found ($configs | length) provider configs"
        
        for config in $configs {
            print $"    🗑️  Deleting ($config)..."
            if $dry_run {
                print $"      (ansi yellow)DRY-RUN: Would delete provider config ($config)(ansi reset)"
            } else {
                kubectl delete providerconfig $config --timeout=30s
                print $"      (ansi green)✓ Deleted(ansi reset)"
            }
        }
    } catch {
        print $"  (ansi yellow)⚠️  No provider configs to delete or error occurred(ansi reset)"
    }
}

# Delete providers
def delete-providers [--dry-run] {
    try {
        let providers = (kubectl get providers --no-headers -o custom-columns=":metadata.name" | lines)
        
        if ($providers | is-empty) {
            print $"  (ansi yellow)ℹ️  No providers found(ansi reset)"
            return
        }
        
        print $"  Found ($providers | length) providers"
        print $"  (ansi yellow)⚠️  Note: Deleting providers will remove all provider CRDs(ansi reset)"
        
        for provider in $providers {
            print $"    🗑️  Deleting ($provider)..."
            if $dry_run {
                print $"      (ansi yellow)DRY-RUN: Would delete provider ($provider)(ansi reset)"
            } else {
                kubectl delete provider $provider --timeout=60s
                print $"      (ansi green)✓ Deleted(ansi reset)"
            }
        }
    } catch {
        print $"  (ansi yellow)⚠️  No providers to delete or error occurred(ansi reset)"
    }
}
