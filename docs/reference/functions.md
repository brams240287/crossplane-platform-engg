# Crossplane Composition Functions

Composition functions are reusable components that transform and enhance your compositions with custom logic.

## Available Functions in This Workspace

### 1. 📛 Naming Convention Function
**Location:** `functions/naming-convention/`

**Purpose:** Enforces consistent naming patterns across all Azure resources

**Configuration:**
```yaml
- step: naming-convention
  functionRef:
    name: function-naming-convention
  input:
    apiVersion: naming.fn.crossplane.io/v1beta1
    kind: NamingConfig
    spec:
      pattern: "{env}-{type}-{purpose}-{region}"
      environment: dev
      enforceAbbreviations: true
```

**Naming Patterns:**
- Resource Groups: `rg-{env}-{purpose}-{region}`
- Virtual Networks: `vnet-{env}-{purpose}-{region}`
- Subnets: `snet-{env}-{purpose}-{az}`
- Storage Accounts: `st{env}{purpose}{random}` (Azure limits: lowercase, no hyphens)

**Example Output:**
```
Input: purpose=backend, env=prod, region=eastus
Output: 
  - rg-prod-backend-eastus
  - vnet-prod-backend-eastus
  - snet-prod-backend-az1
```

---

### 2. 💰 Cost Calculator Function
**Location:** `functions/cost-calculator/`

**Purpose:** Estimates and validates resource costs before provisioning

**Configuration:**
```yaml
- step: cost-calculator
  functionRef:
    name: function-cost-calculator
  input:
    apiVersion: cost.fn.crossplane.io/v1beta1
    kind: CostEstimate
    spec:
      alertThreshold: 5000  # Alert if estimated cost > $5000/month
      blockThreshold: 10000  # Block provisioning if > $10k/month
      costCenter: engineering
```

**Features:**
- Pre-provisioning cost estimation
- Budget alerts and enforcement
- Cost breakdown by resource type
- Monthly/yearly projections
- Cost tagging for chargeback

**Example:**
```
Estimated Monthly Cost:
  - Resource Group: $0
  - Virtual Network: $0  
  - Subnet: $0
  - DDoS Protection: $2,944
  Total: $2,944/month
  
Status: ✅ Within budget ($5,000 threshold)
```

---

### 3. 🔒 Resource Limiter Function
**Location:** `functions/resource-limiter/`

**Purpose:** Enforces resource quotas and prevents over-provisioning

**Configuration:**
```yaml
- step: resource-limits
  functionRef:
    name: function-resource-limiter
  input:
    apiVersion: limits.fn.crossplane.io/v1beta1
    kind: ResourceLimits
    spec:
      maxCost: 5000
      maxInstances: 10
      maxCpuCores: 100
      maxMemoryGB: 400
      enforceHighAvailability: false  # Set true for prod
      allowedRegions: ["eastus", "westus"]
```

**Enforced Limits:**
- Maximum number of resources per type
- Total cost per namespace/team
- Resource SKU restrictions (e.g., only Basic in dev)
- Region restrictions
- High availability requirements (prod only)

**Example:**
```
Dev Environment Limits:
  - Max VMs: 5
  - Max Cost: $500/month
  - Allowed SKUs: Basic, Standard
  - HA Required: No
  
Prod Environment Limits:
  - Max VMs: 50
  - Max Cost: $10,000/month
  - Allowed SKUs: Standard, Premium
  - HA Required: Yes
```

---

### 4. 🏷️ Tagging Function
**Location:** `functions/tagging/`

**Purpose:** Automatically applies and validates resource tags

**Configuration:**
```yaml
- step: tagging
  functionRef:
    name: function-tagging
  input:
    apiVersion: tagging.fn.crossplane.io/v1beta1
    kind: TaggingPolicy
    spec:
      required:
        - costCenter
        - owner
        - environment
      tags:
        managedBy: crossplane
        provisioner: platform-team
        backup: required
      inheritFromNamespace: true
```

**Tag Categories:**

**Required Tags (enforced):**
- `environment`: dev/staging/prod
- `costCenter`: Team/department for billing
- `owner`: Responsible team/person
- `compliance`: Security/compliance level

**Auto-Applied Tags:**
- `managedBy: crossplane`
- `provisionedDate`: 2026-01-27
- `lastModified`: Updated on changes
- `workspace`: Inherited from namespace

**Governance Tags:**
- `backup`: required/optional/none
- `dataClassification`: public/confidential/restricted
- `compliance`: pci-dss/hipaa/sox/none

**Example:**
```yaml
tags:
  # Required (validated)
  environment: prod
  costCenter: engineering
  owner: backend-team
  
  # Auto-applied
  managedBy: crossplane
  provisionedDate: "2026-01-27"
  
  # Governance
  backup: required
  compliance: pci-dss
  dataClassification: confidential
```

---

## Installation Order

```bash
# 1. Install all functions
kubectl apply -f manifests/functions/

# 2. Wait for functions to be healthy
kubectl get functions

# 3. Apply compositions using functions
kubectl apply -f manifests/compositions/network/composition-virtualnetwork-dev.yaml
kubectl apply -f manifests/compositions/network/composition-virtualnetwork-prod.yaml

# 4. Create claims
kubectl create namespace team-backend
kubectl apply -f claims/dev/backend-vnet.yaml
kubectl apply -f claims/prod/backend-vnet.yaml
```

---

## Function Pipeline Order

Functions execute in sequence in the composition pipeline:

```yaml
pipeline:
  - step: naming-convention      # 1. Generate resource names
  - step: cost-calculator        # 2. Estimate costs
  - step: resource-limits        # 3. Validate quotas
  - step: tagging                # 4. Apply tags
  - step: patch-and-transform    # 5. Create resources
```

**Important:** Each function can:
- ✅ Read data from previous steps
- ✅ Add/modify resource definitions
- ✅ Block provisioning on validation failures
- ✅ Add annotations and labels

---

## Implementing Custom Functions

Functions are written in Go and packaged as OCI images:

```bash
# Example: Build naming-convention function
cd functions/naming-convention
go build -o function .
docker build -t your-registry.azurecr.io/function-naming:v1.0.0 .
docker push your-registry.azurecr.io/function-naming:v1.0.0
```

Then reference in compositions:
```yaml
functionRef:
  name: function-naming-convention
  package: your-registry.azurecr.io/function-naming:v1.0.0
```

---

## Best Practices

1. **Naming Convention:** Always use as first step
2. **Cost Calculator:** Use in prod to prevent surprises
3. **Resource Limiter:** Different limits per environment
4. **Tagging:** Required for governance and billing
5. **Validation:** Functions can fail fast before Azure API calls

---

## Troubleshooting

```bash
# Check function status
kubectl get functions

# View function logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/function=function-naming-convention

# Describe composition to see function results
kubectl describe xvirtualnetwork <name>

# Check events for function errors
kubectl get events --field-selector involvedObject.kind=XVirtualNetwork
```

---

## References

- [Crossplane Functions Docs](https://docs.crossplane.io/latest/concepts/composition-functions/)
- [Function SDK](https://github.com/crossplane/function-sdk-go)
- [Example Functions](https://github.com/crossplane-contrib/function-patch-and-transform)
