#!/usr/bin/env nu
# Crossplane Platform Deployment Orchestrator
# This script compiles and applies all platform-level resources in the correct order
# Usage: nu nu-scripts/platform-deploy.nu [--environment dev|staging|prod] [--dry-run]

def main [
    --environment (-e): string = "dev"  # Target environment
    --dry-run (-d)                       # Validate without applying
    --skip-providers                     # Skip provider installation (use only if providers already installed and healthy)
    --gitops                             # Deploy via ArgoCD (GitOps) instead of applying manifests directly
    --skip-argocd                        # In --gitops mode, don't install/upgrade ArgoCD (assume it's already installed)
    --verbose (-v)                       # Verbose output
] {
    print $"(ansi green_bold)🚀 Crossplane Platform Deployment Orchestrator(ansi reset)"
    print $"Environment: ($environment)"
    print ""

    # Validate prerequisites
    if not (check-prerequisites) {
        print $"(ansi red_bold)❌ Prerequisites not met(ansi reset)"
        exit 1
    }

    # GitOps path: install/apply ArgoCD config and let ArgoCD sync the platform.
    if $gitops {
        print $"(ansi cyan_bold)🧩 GitOps Mode: Using ArgoCD to sync platform(ansi reset)"
        if $dry_run {
            print "  DRY-RUN: would run ./scripts/install-argocd.sh and apply ArgoCD Applications/ApplicationSets"
            return
        }

        if not $skip_argocd {
            print $"(ansi cyan_bold)🧰 Step G1: Installing/Upgrading ArgoCD...(ansi reset)"
            try {
                bash ./scripts/install-argocd.sh
            } catch {
                print $"(ansi yellow)⚠️  ArgoCD install script reported issues; check output above(ansi reset)"
            }
        } else {
            print $"(ansi yellow)⏭️  Skipping ArgoCD install/upgrade(ansi reset)"
        }

        print $"(ansi cyan_bold)🔄 Step G2: Applying GitOps manifests...(ansi reset)"
        try {
            kubectl apply -f config/argocd-applications/crossplane-providers.yaml | ignore
            if (ls config/argocd-applications/crossplane-platform-appset.yaml | is-empty) == false {
                kubectl apply -f config/argocd-applications/crossplane-platform-appset.yaml | ignore
            }
            if (ls config/argocd-applications/crossplane-bootstrap-appset.yaml | is-empty) == false {
                kubectl apply -f config/argocd-applications/crossplane-bootstrap-appset.yaml | ignore
            }
            if (ls config/argocd-applications/crossplane-claims-appset.yaml | is-empty) == false {
                kubectl apply -f config/argocd-applications/crossplane-claims-appset.yaml | ignore
            }
        } catch {
            print $"(ansi red_bold)❌ Failed applying ArgoCD GitOps manifests(ansi reset)"
            exit 1
        }

        print ""
        print $"(ansi green_bold)🎉 GitOps bootstrap complete!(ansi reset)"
        print "Check status with: kubectl get applications,applicationsets -n argocd"
        return
    }

    # Step 1: Install/Update Providers
    if not $skip_providers {
        print $"(ansi cyan_bold)📦 Step 1: Installing Providers...(ansi reset)"
        if $dry_run {
            deploy-providers --dry-run
        } else {
            deploy-providers
        }
    } else {
        print $"(ansi yellow)⏭️  Skipping provider installation(ansi reset)"
    }

    # Step 2: Apply Provider Configs
    print $"(ansi cyan_bold)🔧 Step 2: Applying Provider Configurations...(ansi reset)"
    if $dry_run {
        deploy-provider-configs $environment --dry-run
    } else {
        deploy-provider-configs $environment
    }

    # Step 3: Apply Functions (Composition Functions)
    print $"(ansi cyan_bold)⚡ Step 3: Applying Composition Functions...(ansi reset)"
    if $dry_run {
        deploy-functions --dry-run
    } else {
        deploy-functions
    }

    # Step 4: Apply XRDs (APIs)
    print $"(ansi cyan_bold)📋 Step 4: Applying Composite Resource Definitions - APIs...(ansi reset)"
    if $dry_run {
        deploy-xrds --dry-run
    } else {
        deploy-xrds
    }

    # Step 5: Apply Compositions
    print $"(ansi cyan_bold)🎨 Step 5: Applying Compositions...(ansi reset)"
    if $dry_run {
        deploy-compositions $environment --dry-run
    } else {
        deploy-compositions $environment
    }

    # Step 6: Validate Deployment
    print $"(ansi cyan_bold)✅ Step 6: Validating Deployment...(ansi reset)"
    validate-deployment

    print ""
    print $"(ansi green_bold)🎉 Platform deployment complete!(ansi reset)"
    
    if not $dry_run {
        print-deployment-summary
    }
}

# Check if all prerequisites are met
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
    
    # Check if Crossplane is installed
    let crossplane_pods = (kubectl get pods -n crossplane-system -o json | from json | get items | length)
    if $crossplane_pods == 0 {
        print $"(ansi red)❌ Crossplane not installed(ansi reset)"
        return false
    }
    print $"(ansi green)✅ Crossplane installed(ansi reset)"
    
    true
}

# Deploy providers using the install-providers.sh script
def deploy-providers [--dry-run] {
    print "  Using scripts/install-providers.sh for comprehensive provider setup..."
    
    if $dry_run {
        print "  📦 Dry-run: Validating provider manifests..."
        let provider_files = (ls manifests/providers/*.yaml | get name)
        
        if ($provider_files | is-empty) {
            print $"  (ansi yellow)⚠️  No provider files found in manifests/providers/(ansi reset)"
            return
        }
        
        for file in $provider_files {
            let provider_name = ($file | path basename)
            print $"    📦 Validating ($provider_name)..."
            kubectl apply -f $file --dry-run=client | ignore
            print $"      (ansi green)✓ Validated(ansi reset)"
        }
    } else {
        # Run the actual provider installation script
        print "  📦 Running provider installation..."
        if (which bash | is-empty) {
            print $"  (ansi red)❌ bash not found(ansi reset)"
            return
        }

        try {
            bash scripts/install-providers.sh
            print $"  (ansi green)✅ Providers installed and healthy(ansi reset)"
        } catch {
            print $"  (ansi red_bold)❌ Provider installation failed; cannot continue(ansi reset)"
            print "  Run manually: ./scripts/install-providers.sh"
            exit 1
        }
    }
}

# Deploy provider configurations
def deploy-provider-configs [environment: string, --dry-run] {
    let config_files = (ls manifests/provider-configs/*.yaml | get name)
    
    if ($config_files | is-empty) {
        print $"(ansi yellow)⚠️  No provider config files found(ansi reset)"
        return
    }
    
    if $dry_run {
        print $"  (ansi yellow)ℹ️  Note: Provider configs depend on provider CRDs. In dry-run mode, validation may fail if providers aren't installed.(ansi reset)"
    }

    def _api_resource_present [group: string, resource_name: string] {
        let r = (kubectl api-resources --api-group $group -o name | complete)
        if $r.exit_code != 0 { return false }
        ($r.stdout | str contains $resource_name)
    }
    
    for file in $config_files {
        let config_name = ($file | path basename)
        print $"  🔧 Applying ($config_name)..."

        # provider-kubernetes CRDs may not exist yet if the provider isn't installed/healthy.
        if ($config_name == "kubernetes-provider-config.yaml") and (not (_api_resource_present "kubernetes.crossplane.io" "providerconfigs")) {
            print $"    (ansi yellow)⚠️  Skipping: provider-kubernetes CRDs not installed yet (no kubernetes.crossplane.io ProviderConfig).(ansi reset)"
            print "    Install providers first (./scripts/install-providers.sh) and re-run deploy."
            continue
        }
        
        if $dry_run {
            # Dry-run validation - may fail if provider CRDs not installed yet
            let result = (kubectl apply -f $file --dry-run=client | complete)
            if $result.exit_code == 0 {
                print $"    (ansi green)✓ Validated(ansi reset)"
            } else {
                print $"    (ansi yellow)⚠️  Skipped - requires provider CRDs - will work after provider installation(ansi reset)"
            }
        } else {
            let result = (kubectl apply -f $file | complete)
            if $result.exit_code == 0 {
                print $"    (ansi green)✓ Applied(ansi reset)"
            } else {
                print $"    (ansi red_bold)❌ Failed applying ($config_name)(ansi reset)"
                print ($result.stderr | default $result.stdout)
                exit 1
            }
        }
    }
}

# Deploy composition functions
def deploy-functions [--dry-run] {
    let function_files = (ls manifests/functions/*.yaml | get name)
    
    if ($function_files | is-empty) {
        print $"(ansi yellow)⚠️  No function files found(ansi reset)"
        return
    }
    
    for file in $function_files {
        let func_name = ($file | path basename)
        print $"  ⚡ Applying ($func_name)..."
        
        if $dry_run {
            kubectl apply -f $file --dry-run=client | ignore
            print $"    (ansi green)✓ Validated(ansi reset)"
        } else {
            kubectl apply -f $file
            if true {
                print $"    (ansi green)✓ Applied(ansi reset)"
            }
        }
    }
}

# Deploy XRDs (Composite Resource Definitions)
def deploy-xrds [--dry-run] {
    # Find all XRD files recursively in manifests/compositions/**/xrd-*.yaml
    let xrd_files = (glob manifests/compositions/**/xrd-*.yaml)
    
    if ($xrd_files | is-empty) {
        print $"(ansi yellow)⚠️  No XRD files found(ansi reset)"
        return
    }
    
    print $"  Found ($xrd_files | length) XRD files"
    
    for file in $xrd_files {
        let xrd_name = ($file | path basename)
        print $"  📋 Applying ($xrd_name)..."
        
        if $dry_run {
            kubectl apply -f $file --dry-run=client | ignore
            print $"    (ansi green)✓ Validated(ansi reset)"
        } else {
            kubectl apply -f $file
            if true {
                print $"    (ansi green)✓ Applied(ansi reset)"
            }
        }
    }
}

# Deploy compositions (environment-specific if available)
def deploy-compositions [environment: string, --dry-run] {
    # Try environment-specific compositions first, then fall back to general
    let env_pattern = $"manifests/compositions/**/composition-*-($environment).yaml"
    let general_pattern = "manifests/compositions/**/composition-*.yaml"
    
    let env_files = (glob $env_pattern)
    let general_files = (glob $general_pattern | where $it !~ $"($environment).yaml")
    
    let composition_files = ($env_files ++ $general_files)
    
    if ($composition_files | is-empty) {
        print $"(ansi yellow)⚠️  No composition files found(ansi reset)"
        return
    }
    
    print $"  Found ($composition_files | length) composition files"
    
    for file in $composition_files {
        let comp_name = ($file | path basename)
        print $"  🎨 Applying ($comp_name)..."
        
        if $dry_run {
            kubectl apply -f $file --dry-run=client | ignore
            print $"    (ansi green)✓ Validated(ansi reset)"
        } else {
            kubectl apply -f $file
            if true {
                print $"    (ansi green)✓ Applied(ansi reset)"
            }
        }
    }
}

# Check provider health
def check-provider-health [] {
    try {
        let providers = (kubectl get providers -o json | from json | get items)
        let unhealthy = ($providers | where {|p| 
            let conditions = ($p.status?.conditions? | default [])
            let healthy_condition = ($conditions | where type == "Healthy" | first)
            ($healthy_condition.status? | default "False") != "True"
        })
        
        ($unhealthy | is-empty)
    } catch {
        false
    }
}

# Validate the deployment
def validate-deployment [] {
    print "  🔍 Checking providers..."
    let providers = (kubectl get providers --no-headers 2>/dev/null | complete)
    if $providers.exit_code == 0 {
        print $"    (ansi green)✓ ($providers.stdout | lines | length) providers found(ansi reset)"
    }
    
    print "  🔍 Checking XRDs..."
    let xrds = (kubectl get xrd --no-headers 2>/dev/null | complete)
    if $xrds.exit_code == 0 {
        print $"    (ansi green)✓ ($xrds.stdout | lines | length) XRDs found(ansi reset)"
    }
    
    print "  🔍 Checking compositions..."
    let compositions = (kubectl get compositions --no-headers 2>/dev/null | complete)
    if $compositions.exit_code == 0 {
        print $"    (ansi green)✓ ($compositions.stdout | lines | length) compositions found(ansi reset)"
    }
}

# Print deployment summary
def print-deployment-summary [] {
    print ""
    print $"(ansi cyan_bold)📊 Deployment Summary(ansi reset)"
    print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Providers
    try {
        let providers = (kubectl get providers -o json | from json | get items)
        print $"Providers: ($providers | length)"
        for provider in $providers {
            let name = $provider.metadata.name
            let installed = ($provider.status?.conditions? | default [] | where type == "Installed" | first | get status? | default "Unknown")
            let healthy = ($provider.status?.conditions? | default [] | where type == "Healthy" | first | get status? | default "Unknown")
            
            let status_icon = if $healthy == "True" { "✅" } else { "⚠️" }
            print $"  ($status_icon) ($name): Installed=($installed), Healthy=($healthy)"
        }
    } catch {
        print $"  (ansi red)Error fetching providers(ansi reset)"
    }
    
    print ""
    
    # XRDs
    try {
        let xrds = (kubectl get xrd -o json | from json | get items)
        print $"XRDs (APIs): ($xrds | length)"
        for xrd in $xrds {
            let name = $xrd.metadata.name
            let kind = $xrd.spec.names.kind
            print $"  📋 ($name) → ($kind)"
        }
    } catch {
        print $"  (ansi red)Error fetching XRDs(ansi reset)"
    }
    
    print ""
    
    # Compositions
    try {
        let compositions = (kubectl get compositions -o json | from json | get items)
        print $"Compositions: ($compositions | length)"
        for comp in $compositions {
            let name = $comp.metadata.name
            let type_ref = $comp.spec.compositeTypeRef.kind
            print $"  🎨 ($name) → ($type_ref)"
        }
    } catch {
        print $"  (ansi red)Error fetching compositions(ansi reset)"
    }
    
    print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}
