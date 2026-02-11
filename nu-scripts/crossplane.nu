# Crossplane Helper Commands for Nushell
# Source this file: source nu-scripts/crossplane.nu

# Internal helper: run kubectl and capture stdout/stderr/exit code.
def _kubectl_complete [args: list<string>] {
  ^kubectl ...$args | complete
}

# Internal helper: run kubectl -o json and parse stdout.
def _kubectl_json [args: list<string>] {
  let r = (_kubectl_complete $args)
  if $r.exit_code != 0 {
    error make {msg: ($r.stderr | default $r.stdout)}
  }
  $r.stdout | from json
}

# Internal helper: try `kubectl get <kind> -A`, fall back to cluster-scoped `kubectl get <kind>`
def _kubectl_get_flexible [kind: string, namespace?: string] {
  if ($namespace | default "" | str length) > 0 {
    let r = (_kubectl_complete ["get" $kind "-n" $namespace])
    return ($r.stdout + $r.stderr)
  }

  let r_all = (_kubectl_complete ["get" $kind "-A"])
  if $r_all.exit_code == 0 {
    return ($r_all.stdout + $r_all.stderr)
  }

  let combined = ($r_all.stdout + $r_all.stderr)
  if ($combined | str contains "a cluster-scoped resource") or ($combined | str contains "unknown flag") {
    let r_one = (_kubectl_complete ["get" $kind])
    ($r_one.stdout + $r_one.stderr)
  } else {
    $combined
  }
}

# Internal helper: list claim kinds from XRDs
def _xrd_claim_kinds [] {
  try {
    (_kubectl_json ["get" "xrd" "-o" "json"])
    | get items
    | each {|x| $x.spec?.claimNames?.kind? | default "" }
    | where {|k| $k != "" }
    | uniq
  } catch {
    []
  }
}

# Internal helper: get current kubectl namespace (defaults to "default")
def _kubectl_current_namespace [] {
  let ns = ((^kubectl config view --minify -o jsonpath='{..namespace}' | complete).stdout | str trim)
  if ($ns | str length) > 0 { $ns } else { "default" }
}

# Internal helper: XRD records with claim<->XR mapping
def _xrd_claim_kind_records [] {
  try {
    (_kubectl_json ["get" "xrd" "-o" "json"])
    | get items
    | each {|x|
        {
          claimKind: ($x.spec?.claimNames?.kind? | default "")
          claimPlural: ($x.spec?.claimNames?.plural? | default "")
          xrKind: ($x.spec?.names?.kind? | default "")
          xrPlural: ($x.spec?.names?.plural? | default "")
        }
      }
    | where {|r| ($r.claimKind != "") or ($r.xrKind != "") }
  } catch {
    []
  }
}

# Internal helper: does a given resource/name exist?
def _kubectl_resource_exists [resource: string, name: string, namespace?: string] {
  if ($namespace | default "" | str length) > 0 {
    let r = (^kubectl get $resource $name -n $namespace -o name | complete)
    $r.exit_code == 0
  } else {
    let r = (^kubectl get $resource $name -o name | complete)
    $r.exit_code == 0
  }
}

# Internal helper: delete a namespaced resource, falling back to cluster-scoped when needed
def _kubectl_delete_flexible [resource: string, name: string, namespace?: string] {
  if ($namespace | default "" | str length) > 0 {
    let r = (^kubectl delete $resource $name -n $namespace | complete)
    let combined = ($r.stdout + $r.stderr)
    if ($combined | str contains "a cluster-scoped resource") or ($combined | str contains "unknown flag: -n") {
      let r2 = (^kubectl delete $resource $name | complete)
      let combined2 = ($r2.stdout + $r2.stderr)
      if $r2.exit_code != 0 {
        error make {msg: $combined2}
      }
      $combined2
    } else {
      if $r.exit_code != 0 {
        error make {msg: $combined}
      }
      $combined
    }
  } else {
    let r = (^kubectl delete $resource $name | complete)
    let combined = ($r.stdout + $r.stderr)
    if $r.exit_code != 0 {
      error make {msg: $combined}
    }
    $combined
  }
}

# Get all Crossplane managed resources
export def "xp resources" [] {
  try {
    (_kubectl_json ["get" "managed" "-o" "json"])
    | get items
    | each {|x|
        {
          name: ($x.metadata?.name? | default "")
          namespace: ($x.metadata?.namespace? | default "")
          providerConfig: ($x.spec?.providerConfigRef?.name? | default "")
          conditions: ($x.status?.conditions? | default [])
        }
      }
  } catch {
    []
  }
}

# Check provider health status
export def "xp health" [] {
  try {
    (_kubectl_json ["get" "providers" "-o" "json"])
    | get items
    | select metadata.name status.conditions
    | flatten
    | where type == "Healthy" or type == "Installed"
  } catch {
    []
  }
}

# Get detailed provider information
export def "xp provider" [name: string] {
  (_kubectl_json ["get" "provider" $name "-o" "json"])
}

# Watch a specific claim's status
export def "xp watch-claim" [claim: string, --kind (-k): string = "virtualnetwork", --namespace (-n): string = "default"] {
  (_kubectl_json ["get" $kind $claim "-n" $namespace "-o" "json"])
  | get status
}

# List all compositions with their types
export def "xp compositions" [] {
  try {
    (_kubectl_json ["get" "compositions" "-o" "json"])
    | get items
    | select metadata.name spec.compositeTypeRef.kind metadata.labels
  } catch {
    []
  }
}

# List all XRDs (Composite Resource Definitions)
export def "xp xrds" [] {
  try {
    (_kubectl_json ["get" "xrd" "-o" "json"])
    | get items
    | each {|x|
        {
          name: ($x.metadata?.name? | default "")
          group: ($x.spec?.group? | default "")
          xrKind: ($x.spec?.names?.kind? | default "")
          claimKind: ($x.spec?.claimNames?.kind? | default "")
        }
      }
  } catch {
    print "Failed to list XRDs. Is Crossplane installed and does 'kubectl get xrd' work?"
    []
  }
}

# Get all claims across namespaces
export def "xp claims" [--namespace (-n): string] {
  let kinds = (_xrd_claim_kinds)
  if ($kinds | is-empty) {
    print "No claim kinds found via XRDs"
    return
  }

  for kind in $kinds {
    print $"\n=== Claims: ($kind) ==="
    let out = (_kubectl_get_flexible $kind $namespace)
    if ($out | str contains "No resources found") {
      print "No resources found"
    } else {
      print $out
    }
  }
}

# Check Azure resources created by Crossplane
export def "xp azure-resources" [] {
  az resource list --query "[?tags.crossplane=='true']" -o json | from json
}

# Validate composition files before applying
export def "xp validate" [] {
  bash ./scripts/validate-compositions.sh
}

# Get logs from Crossplane core
export def "xp logs-core" [--follow (-f)] {
  if $follow {
    kubectl logs -n crossplane-system -l app=crossplane --follow
  } else {
    kubectl logs -n crossplane-system -l app=crossplane --tail=100
  }
}

# Get logs from a specific provider
export def "xp logs-provider" [provider: string, --follow (-f)] {
  if $follow {
    kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=$provider --follow
  } else {
    kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=$provider --tail=100
  }
}

# Describe a managed resource with events
export def "xp describe" [resource: string, --namespace (-n): string = "default"] {
  print "=== Resource Details ==="
  kubectl describe -n $namespace $resource
  print "\n=== Recent Events ==="
  kubectl get events -n $namespace --field-selector involvedObject.name=$resource --sort-by='.lastTimestamp'
}

# Install Crossplane using the script
export def "xp install" [] {
  bash ./scripts/install-crossplane.sh
}

# Install providers using the script
export def "xp install-providers" [] {
  bash ./scripts/install-providers.sh
}

# Quick status overview
export def "xp status" [--namespace (-n): string] {
  print "=== Crossplane Core ==="
  ^kubectl get pods -n crossplane-system -l app=crossplane
  
  print "\n=== Providers ==="
  ^kubectl get providers
  
  print "\n=== Compositions ==="
  let comp_output = ((_kubectl_complete ["get" "compositions"]).stdout | default "")
  if ($comp_output | str contains "No resources found") {
    print "No compositions found"
  } else {
    print $comp_output
  }
  
  print "\n=== Claims ==="

  # Prefer XRD-discovered claim kinds; also include common kinds for convenience.
  let claim_kinds = ((_xrd_claim_kinds) | default [] | append "virtualnetwork" | append "xvirtualnetwork" | uniq)
  for kind in $claim_kinds {
    let out = (_kubectl_get_flexible $kind $namespace)
    if not ($out | str contains "the server doesn't have a resource type") {
      if ($out | str contains "No resources found") {
        continue
      }
      print $"--- ($kind) ---"
      print $out
    }
  }
  
  print "\n=== Managed Resources ==="
  let managed_output = ((_kubectl_complete ["get" "managed"]).stdout | default "")
  if ($managed_output | str contains "No resources found") {
    print "No resources found"
  } else {
    print $managed_output
  }
  let r = (_kubectl_complete ["get" "managed" "--no-headers"])
  let managed_count = if $r.exit_code == 0 {
    ($r.stdout | lines | where {|l| ($l | str trim) != "" } | length)
  } else {
    0
  }
  print $"($managed_count) managed resources"
}

# Apply a claim from claims directory
export def "xp apply-claim" [environment: string, file: string] {
  let filepath = $"claims/($environment)/($file)"
  kubectl apply -f $filepath
  print $"Applied claim from ($filepath)"
}

# Delete a claim (or an XR)
export def "xp delete-claim" [name: string, --kind (-k): string, --namespace (-n): string] {
  let ns = if ($namespace | default "" | str length) > 0 { $namespace } else { (_kubectl_current_namespace) }

  # If kind is explicitly provided, honor it and let kubectl decide scope.
  if ($kind | default "" | str length) > 0 {
    print $"Deleting ($kind)/($name) (namespace: ($ns))"
    print (_kubectl_delete_flexible $kind $name $ns)
    return
  }

  # Auto-detect whether this name refers to a claim (namespaced) or XR (cluster-scoped)
  # using XRD definitions. If ambiguous, ask for --kind.
  let records = (_xrd_claim_kind_records)
  let candidates = (
    $records
    | each {|r|
        [
          {resource: $r.claimPlural, scope: "namespaced"}
          {resource: $r.claimKind, scope: "namespaced"}
          {resource: $r.xrPlural, scope: "cluster"}
          {resource: $r.xrKind, scope: "cluster"}
        ]
      }
    | flatten
    | where {|c| ($c.resource | default "" | str length) > 0 }
    | group-by resource
    | values
    | each {|g| $g | first }
  )

  let matches = (
    $candidates
    | where {|c|
        if $c.scope == "namespaced" {
          _kubectl_resource_exists $c.resource $name $ns
        } else {
          _kubectl_resource_exists $c.resource $name
        }
      }
  )

  if ($matches | length) == 1 {
    let chosen = ($matches | get 0)
    if $chosen.scope == "namespaced" {
      print $"Deleting ($chosen.resource)/($name) in namespace ($ns)"
      print (_kubectl_delete_flexible $chosen.resource $name $ns)
    } else {
      print $"Deleting ($chosen.resource)/($name) (cluster-scoped)"
      print (_kubectl_delete_flexible $chosen.resource $name)
    }
    return
  }

  if ($matches | length) > 1 {
    print "Multiple resources match this name; specify --kind/-k explicitly."
    print ($matches | select resource scope)
    error make {msg: "Ambiguous delete target"}
  }

  # Backwards-compatible default.
  print $"No matching claim/XR detected; falling back to virtualnetwork/($name) in namespace ($ns)"
  print (_kubectl_delete_flexible "virtualnetwork" $name $ns)
}

# ArgoCD helpers
export def "xp argocd-install" [] {
  bash ./scripts/install-argocd.sh
}

export def "xp argocd-password" [] {
  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
  print ""
}

export def "xp argocd-status" [] {
  print "=== ArgoCD Pods ==="
  _kubectl_get_flexible "pods" "argocd" | print
  print "\n=== Applications ==="
  _kubectl_get_flexible "applications" "argocd" | print
  print "\n=== ApplicationSets ==="
  _kubectl_get_flexible "applicationsets" "argocd" | print
}

export def "xp argocd-port-forward" [--port (-p): int = 8080] {
  print $"Port-forwarding ArgoCD on https://localhost:($port)"
  bash -c $"kubectl port-forward svc/argocd-server -n argocd ($port):443"
}

export def "xp gitops-apply" [] {
  kubectl apply -f config/argocd-applications/crossplane-providers.yaml
  if (ls config/argocd-applications/crossplane-platform-appset.yaml | is-empty) == false {
    kubectl apply -f config/argocd-applications/crossplane-platform-appset.yaml
  }
  if (ls config/argocd-applications/crossplane-bootstrap-appset.yaml | is-empty) == false {
    kubectl apply -f config/argocd-applications/crossplane-bootstrap-appset.yaml
  }
  if (ls config/argocd-applications/crossplane-claims-appset.yaml | is-empty) == false {
    kubectl apply -f config/argocd-applications/crossplane-claims-appset.yaml
  }
}

# Get composition function status
export def "xp functions" [] {
  try {
    (_kubectl_json ["get" "functions" "-o" "json"])
    | get items
    | select metadata.name spec.package status.conditions
  } catch {
    []
  }
}

# Tail all Crossplane-related logs
export def "xp logs-all" [] {
  kubectl logs -n crossplane-system -l "app in (crossplane)" --all-containers=true --prefix=true --follow
}

# Get provider configuration
export def "xp provider-config" [name: string = "default"] {
  (_kubectl_json ["get" "providerconfig" $name "-o" "json"])
}

# List all managed resource types available
export def "xp api-resources" [] {
  kubectl api-resources --api-group="*.upbound.io" -o wide
}

# Quick troubleshoot command
export def "xp troubleshoot" [resource: string, --namespace (-n): string = "default"] {
  print $"=== Troubleshooting ($resource) in namespace ($namespace) ==="
  
  print "\n1. Resource Status:"
  kubectl get -n $namespace $resource -o yaml | from yaml | get status
  
  print "\n2. Recent Events:"
  kubectl get events -n $namespace --field-selector involvedObject.name=$resource --sort-by='.lastTimestamp'
  
  print "\n3. Related Resources:"
  kubectl get managed -n $namespace -o json | from json | get items | where metadata.ownerReferences != null
  
  print "\n4. Provider Logs (last 50 lines):"
  kubectl logs -n crossplane-system -l "pkg.crossplane.io/provider" --tail=50
}

# Export composition to a file
export def "xp export-composition" [name: string, output: string] {
  kubectl get composition $name -o yaml | save $output
  print $"Exported composition ($name) to ($output)"
}

# Generate a new claim template
export def "xp new-claim" [kind: string, name: string, environment: string = "dev"] {
  let filepath = $"claims/($environment)/($name).yaml"
  
  $"apiVersion: azure.platform.io/v1alpha1
kind: ($kind)
metadata:
  name: ($name)
  namespace: default
spec:
  parameters:
    location: eastus
  compositionSelector:
    matchLabels:
      provider: azure
      environment: ($environment)" | save $filepath
  
  print $"Created claim template at ($filepath)"
}

# Show help for all xp commands
export def "xp help" [] {
  print "Crossplane Helper Commands for Nushell\n"
  print "Basic Commands:"
  print "  xp status [-n ns]       - Show overall Crossplane status (optionally scoped)"
  print "  xp health              - Check provider health"
  print "  xp resources           - List all managed resources"
  print "  xp compositions        - List all compositions"
  print "  xp xrds                - List all XRDs"
  print "  xp claims [-n ns]       - List claims by kind (from XRDs)"
  print ""
  print "Management:"
  print "  xp install             - Install Crossplane"
  print "  xp install-providers   - Install Azure providers"
  print "  xp argocd-install       - Install/upgrade ArgoCD + GitOps config"
  print "  xp validate            - Validate compositions"
  print "  xp apply-claim <env> <file> - Apply a claim"
  print "  xp delete-claim <name> [-k kind] [-n ns] - Delete a claim or XR (auto-detects if -k omitted)"
  print ""
  print "Inspection:"
  print "  xp describe <resource> - Describe a resource with events"
  print "  xp watch-claim <name> [-k kind] [-n ns] - Watch claim status"
  print "  xp troubleshoot <res>  - Troubleshoot a resource"
  print "  xp azure-resources     - List Azure resources"
  print "  xp argocd-status       - Show ArgoCD apps/appsets"
  print "  xp argocd-password     - Print ArgoCD admin password"
  print "  xp argocd-port-forward - Port-forward ArgoCD UI"
  print "  xp gitops-apply        - Apply Crossplane ArgoCD config manifests"
  print ""
  print "Logs:"
  print "  xp logs-core           - Show Crossplane core logs"
  print "  xp logs-provider <name> - Show provider logs"
  print "  xp logs-all            - Tail all logs"
  print ""
  print "Utilities:"
  print "  xp new-claim <kind> <name> [env] - Generate claim template"
  print "  xp export-composition <name> <output> - Export composition"
  print "  xp api-resources       - List available API resources"
  print ""
  print "Add -h or --help to any command for more details"
}
