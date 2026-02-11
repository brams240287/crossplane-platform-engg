Azure Provisioner - Resources and Configuration Documentation
Overview
This document provides comprehensive details about all Azure resources created by the Pulumi-based Azure Infrastructure as Code (IaaC) provisioner, along with their configuration options.

Table of Contents
Resource Groups
Networking Resources
Compute Resources
Kubernetes/Container Resources
Storage Resources
Database Resources
Security Resources
Application Gateway & WAF
Backup & Recovery
Cache Resources
DNS Resources
Monitoring & Diagnostics
Configuration Structure
Resource Groups
Azure Resource Group
Provisioner Module: plt_resource_azure.py

Purpose: Container for Azure resources, providing logical grouping and management.

Configuration:

resourceGroups:
  - name: rg-sample-dev-main
Generated Resources:

Resource Group with specified name
Automatically tagged with project metadata
Location inherited from project configuration
Networking Resources
Virtual Network (VNet)
Provisioner Module: plt_network_azure.py

Purpose: Provides isolated network infrastructure for Azure resources.

Configuration:

network:
  active: true
  resourceGroup: rg-sample-dev-main
  name: vnet-sample-dev
  ipVersion: 4  # IPv4 or IPv6
  cidr: 10.80.163.0/25
Features:

IPv4/IPv6 support
Multiple subnet support
VNet peering capabilities
Service endpoints
Network security groups
Subnets
Configuration:

subnet:
  - name: snet-sample-dev-cluster
    cidr: 10.80.167.0/26
    cluster: true  # For AKS/ARO cluster
  - name: snet-sample-dev-db
    cidr: 10.80.167.96/28
    delegation:
      name: fs
      enabled: true
      service: Microsoft.Storage
      service_name: Microsoft.DBforPostgreSQL/flexibleServers
Features:

CIDR-based IP allocation
Service delegation (for PostgreSQL, Storage, etc.)
Cluster-specific subnets
Service endpoint configuration
VNet Peering
Configuration:

peering:
  - name: sample-dev-to-devops
    bidirectional:
      enable: true
      name: devops-to-sample-dev
    peeringProperties:
      peering_state: Connected
      use_remote_gateways: false
      allow_virtual_network_access: true
      allow_forwarded_traffic: true
      allow_gateway_transit: true
    remoteNetwork:
      id: /subscriptions/.../virtualNetworks/vnet-sample-dev-devops
      name: vnet-sample-dev-devops
Features:

Bidirectional peering support
Gateway transit options
Traffic forwarding control
Remote gateway usage
NAT Gateway
Configuration:

natgateway:
  name: sample-nat-gateway
  resourceGroup: rg-dev-main
  publicip:
    name: nat-gateway-public-ip
    allocation_method: Static
    sku_name: Standard
  sku_name: Standard
  zones:
    - '1'
Features:

Static public IP assignment
Zone redundancy
Outbound internet connectivity for private resources
Network Security Groups (NSG)
Configuration:

nsg:
  name: sample-aks-nsg
  resourceGroup: rg-dev-main
  security_rules:
    - name: Allow-AzureServices
      priority: 1000
      direction: Outbound
      access: Allow
      protocol: "*"
      source_port_range: "*"
      destination_port_range: "*"
      source_address_prefix: "*"
      destination_address_prefix: AzureCloud
Features:

Inbound/Outbound rules
Priority-based rule ordering
Service tag support (AzureCloud, Internet, etc.)
Protocol-specific filtering
Compute Resources
Virtual Machines (VMs)
Provisioner Module: plt_vm_azure.py, plt_compute_azure.py

Purpose: Standalone virtual machines for application hosting, jump hosts, or specific workloads.

Supported OS Types:

Linux (Ubuntu, RHEL, etc.)
Windows Server
Configuration:

computing:
  sshKeypairs:
    - name: devops
  imageReferences:
    - name: ubuntu-22.04-lts
      publisher: canonical
      product: 0001-com-ubuntu-server-jammy
      sku: 22_04-lts-gen2
      version: latest
      type: LinuxComputeInstance
    - name: windows-server-2022
      publisher: MicrosoftWindowsServer
      product: WindowsServer
      sku: 2022-datacenter-g2
      version: latest
      type: WindowsComputeInstance
Features:

SSH key pair management
Public/Private IP assignment
Accelerated networking
Managed identity support
Custom image support
Proximity placement group integration
Virtual Machine Scale Sets (VMSS)
Provisioner Module: plt_virtual_machine_scale_sets.py

Purpose: Scalable compute resources with auto-scaling capabilities.

Features:

Auto-scaling rules
Load balancer integration
Availability zone support
Custom script extensions
Jump Host
Provisioner Module: plt_jumphost_azure.py

Purpose: Secure access point for private network resources.

Features:

Public IP for external access
SSH key authentication
Network security group rules
Integration with private networks
Proximity Placement Group (PPG)
Provisioner Module: plt_proximity_placement_group.py

Configuration:

ppg:
  name: ppg-sample-dev-devops
  resourceGroup: rg-sample-dev-devops
  enabled: true
  given: false  # Use existing or create new
  vm_sizes:
    - Standard_B2s
    - Standard_B2ms
    - Standard_F8s_v2
Purpose: Co-locate VMs for low network latency.

Kubernetes/Container Resources
Azure Kubernetes Service (AKS)
Provisioner Module: plt_k8s_cluster_azure.py

Purpose: Managed Kubernetes cluster for container orchestration.

Configuration:

cluster:
  name: sample-dev-cluster
  resourceGroup: rg-sample-dev-main
  type: AKS
  private: true
  sku:
    name: Base
    tier: Free  # or Standard, Premium
  apiDnsPrefix: sample-dev-api
  version: 1.32.4
  outbound:
    type: UserAssignedNATGateway
    loadbalancer_sku: STANDARD
  user_assigned_identity_name: mid-sample-dev
Features:

Private/Public cluster options
Multiple node pools
Azure CNI networking
Auto-scaling support
RBAC integration
ACR integration
Managed identity
Node Pools
Configuration:

masterPool:
  name: controlpool
  count: 3
  enable_auto_scaling: false
  max_pods: 110
  availabilityZones:
    - "1"
  labels:
    - name: pasx.io/type
      value: control
  instanceDefinition:
    sku: Standard_B2s
    volumes:
      - name: boot-volume
        sizeGB: 120
        type: standard
        boot: true

instancePools:
  - name: workerPool
    count: 3
    enable_auto_scaling: true
    min_count: 1
    max_count: 5
    node_taints:
      - key=value:NoSchedule
Features:

Control plane and worker node pools
Auto-scaling per node pool
Node labels and taints
Zone-specific deployment
Custom VM sizes
Persistent Volumes
Configuration:

persistentVolumes:
  - name: pv-platform-logging
    fileshare_name: platform-logging
    capacity: 100Gi
    accessModes:
      - ReadWriteOnce
    reclaimPolicy: Retain
    readonly: false
Features:

Azure Files integration
Multiple access modes (ReadWriteOnce, ReadWriteMany, ReadOnlyMany)
Retention policies
Azure Red Hat OpenShift (ARO)
Provisioner Module: plt_aro_cluster_azure.py

Purpose: Managed OpenShift cluster for enterprise container workloads.

Configuration:

cluster:
  type: ARO
  version: "4.x"
  private: true
  pullSecret:
    vault:
      name: keyvault-name
    pullSecretName: secret-name
Features:

Private/Public API server
Service principal authentication
Red Hat pull secret management
Custom networking (pod CIDR, service CIDR)
Container Registry Integration
Configuration:

registries:
  - name: pasxregistry
    type: ACR_ATTACHED
    domain: pasxregistry.azurecr.io
    id: /subscriptions/.../registries/pasxregistry
Features:

ACR pull role assignment
Automatic authentication
Multi-registry support
Kubernetes Secrets
Provisioner Module: k8s_util/k8s_secrets.py

Configuration:

secrets:
  - name: pasx-config-pkeys
    keyvaultName: kv-sample-dev
    namespace: pasx-operator
Features:

Azure Key Vault integration
Namespace-specific secrets
Automatic synchronization
Storage Resources
Storage Account
Provisioner Module: plt_storage_azure.py

Purpose: General-purpose storage for files, blobs, queues, and tables.

Configuration:

storageAccount:
  name: stsampledev
  resourceGroup: rg-sample-dev-main
  sku: Standard_LRS  # or Standard_GRS, Premium_LRS
  kind: StorageV2
  additional_allowed_subnet_ids:
    - /subscriptions/.../subnets/subnet-name
Features:

Multiple redundancy options (LRS, GRS, ZRS, GZRS)
Private endpoints
Network access restrictions
Firewall rules
File Shares
Configuration:

fileshares:
  - name: platform-logging
    quota: 100  # GB
  - name: cups-config
    quota: 15
Features:

SMB 3.0 protocol
Quota management
Azure Files Premium support
Integration with AKS persistent volumes
Database Resources
PostgreSQL Flexible Server
Provisioner Module: plt_postgres_flexible_azure.py

Purpose: Managed PostgreSQL database service.

Configuration:

postgres:
  name: pg-sample-dev
  resourceGroup: rg-sample-dev-main
  subnet: snet-sample-dev-db
  username: devops
  password_ref:
    secret_name: POSTGRES-ADMIN-PASSWORD
    keyvault_name: kv-sample-dev
  version: "15"
  storage_mb: 262144  # 256 GB
  sku: GP_Standard_D4ds_v4
  zone: "1"
  ha_enabled: false
  ha_mode: ZoneRedundant
  retention_days: 30
Features:

High availability (zone redundant)
Automated backups
Point-in-time restore
Private endpoint/VNet integration
Custom parameters
Multiple database support
Database Configuration
Configuration:

database:
  - name: PDA
    collation: en_US.utf8
    charset: utf8
  - name: MES
    collation: en_US.utf8
    charset: utf8
PostgreSQL Parameters
parameters:
  max_connections: 300
  shared_buffers: 518144
  effective_cache_size: 1572864
  work_mem: 8192
  maintenance_work_mem: 65536
  log_min_duration_statement: 10000
  max_prepared_transactions: 64
DNS Entry for PostgreSQL
Configuration:

dnsEntry:
  name: sample-dev-pg-dns
  subdomainName: db
  dnsZone: sample-dev.saas.azure.io
  recordType: A
  ttl: 60
Security Resources
Azure Key Vault
Provisioner Module: plt_keyvault_azure.py

Purpose: Secure storage for secrets, keys, and certificates.

Configuration:

keyvault:
  name: kvsampledev
  resourceGroup: rg-sample-dev-main
  retention: 7  # Soft delete retention days
  sku: STANDARD  # or PREMIUM
  tenant_id: <tenant-id>
  permissionModel: rbac  # or vault
  public: false
  additional_allowed_subnet_ids:
    - /subscriptions/.../subnets/subnet-name
Features:

Soft delete with retention
Purge protection
RBAC or access policy authorization
Private endpoints
Network access control
Firewall rules
Key Vault RBAC Roles
Configuration:

rbac_roles:
  - name: SecretOfficer to Service Principal
    principal_id: <principal-id>
    principal_type: ServicePrincipal  # or User, Group
    role_definition_id: /providers/Microsoft.Authorization/roleDefinitions/...
Supported Roles:

Key Vault Administrator
Key Vault Secrets Officer
Key Vault Secrets User
Key Vault Crypto Officer
Key Vault Certificates Officer
Secrets Management
Configuration:

secrets:
  - name: POSTGRES-ADMIN-PASSWORD
    length: 20
    special_chr: _.~
    source: generate  # or manual
  - name: CUPS-ADMIN-PASSWORD
    length: 20
    special_chr: "!?"
    source: generate
Features:

Auto-generation with custom character sets
Length specification
Special character control
Manual secret upload
Certificate storage
SSH Key Pairs
Provisioner Module: plt_key_pairs.py

Configuration:

sshKeypairs:
  - name: devops
Features:

RSA key pair generation
Private key stored in Key Vault
Public key distribution to VMs
2048-bit or 4096-bit keys
Managed Identities
Provisioner Module: plt_credentials_azure.py

Purpose: Azure AD identity for resources to access other Azure services.

Types:

System-assigned identity
User-assigned identity
Features:

Automatic credential rotation
RBAC role assignments
Resource-level permissions
Application Gateway & WAF
Application Gateway
Provisioner Module: plt_application_gw_azure.py

Purpose: Layer 7 load balancer with WAF capabilities.

Configuration:

applicationgw:
  name: appgw-sample-dev
  resourceGroup: rg-sample-dev-main
  sku:
    name: WAF_v2
    tier: WAF_v2
    capacity: 2
  publicip:
    name: appgw-public-ip-sample-dev
    public_ip_allocation_method: static
    sku: Standard
Features:

Web Application Firewall (WAF)
SSL termination
Multiple site hosting
URL-based routing
Public and private frontend IPs
Frontend Configuration
Configuration:

frontend_ip:
  - name: appgw-frontend-public-ip-sample-dev
  - name: appgw-frontend-private-ip-sample-dev
    private_ip_allocation_method: static

frontend_port:
  name: appGatewayFrontendPort
  port: 80
Backend Configuration
Configuration:

backend_address_pools:
  name: defaultBackendPool

backend_http_settings:
  name: defaultBackendHttpSettings
  port: 80
  protocol: Http
Routing Rules
Configuration:

http_listeners:
  name: appGatewayHttpListener
  protocol: Http

request_routing_rules:
  name: appGatewayRule
  priority: 100
  rule_type: Basic
WAF Policy
Provisioner Module: plt_waf_policy_azure.py

Configuration:

wafpolicy:
  name: wafpolicy-sample-dev
  resourceGroup: rg-sample-dev-main
  custom_rules:
    - name: ExampleCustomRule
      priority: 1
      rule_type: MatchRule
      match_conditions:
        - match_variables:
            - variable_name: RemoteAddr
          operator: IPMatch
          match_values:
            - 1.2.3.4
      action: Allow
  managed_rules:
    managed_rule_sets:
      - rule_set_type: OWASP
        rule_set_version: "3.2"
      - rule_set_type: Microsoft_BotManagerRuleSet
        rule_set_version: "0.1"
  policy_settings:
    mode: Detection  # or Prevention
    state: Enabled
    file_upload_limit_in_mb: 100
    request_body_inspect_limit_in_kb: 128
Features:

OWASP rule sets
Bot protection
Custom rules
Detection/Prevention mode
Geo-filtering
Rate limiting
Backup & Recovery
Azure Backup for File Shares
Provisioner Module: plt_backup_azure.py

Purpose: Automated backup and recovery for Azure File Shares.

Configuration:

backup:
  enable: true
  resourceGroup: rg-sample-dev-main
  vault_name: rv-sample-dev-backup
  fabric_name: Azure
  public_network_access: Enabled
  sku_args:
    name: RS0
    tier: Standard
Backup Policy:

backup_policy:
  name: backup-policy-sample-dev
  retention_times: 03:00:00.000Z
  time_zone: UTC
  work_load_type: AzureFileShare
  schedule_policy:
    schedule_run_frequency: Daily
    schedule_run_times: 03:00:00.000Z
Retention Schedules:

daily_schedule:
  count: 30
  duration_type: Days

weekly_schedule:
  enable: true
  days_of_week:
    - SATURDAY
  retention_duration:
    count: 12
    duration_type: Weeks

monthly_schedule:
  enable: true
  count: 60
  duration_type: Months
  retention_schedule_format_type: Weekly
  days_of_week:
    - SUNDAY
  weeks_of_month:
    - FIRST

yearly_schedule:
  enable: false
  months_of_year:
    - JANUARY
  count: 1
  duration_type: Years
Features:

Daily, weekly, monthly, yearly retention
Point-in-time restore
Instant restore snapshots
Cross-region restore
Soft delete protection
Cache Resources
Azure Cache for Redis
Provisioner Module: plt_cache_redis_azure.py

Purpose: In-memory data store for caching and session management.

Configuration:

cacheRedis:
  name: redis-sample-dev
  resourceGroup: rg-sample-dev-main
  networks:
    - snet-sample-dev-cache
  properties:
    sku:
      name: Premium  # Basic, Standard, Premium
      family: P
      capacity: 1
    redis_configuration:
      maxmemory_policy: allkeys-lru
      maxmemory_reserved: 50
    public_network_access: false
Features:

VNet integration
Redis clustering (Premium tier)
Data persistence
Geo-replication
SSL/TLS encryption
Access keys stored in Key Vault
DNS Resources
DNS Zone & Records
Provisioner Module: plt_dns_azure.py

Purpose: Domain name resolution for Azure resources.

Configuration:

dnsEntry:
  parent_subscriptionId: <subscription-id>
  parent_dnsZoneRg: rg-saas-azure
  parent_dnsZone_Name: saas.azure.io
  child_dnsZoneRg: rg-sample-dev-main
  child_dnsZone_Name: sample-dev.saas.azure.io
  child_record_set_name: sample-dev
Features:

Parent-child zone relationships
NS record delegation
A, AAAA, CNAME, TXT records
Private DNS zones
Auto-registration for VNet resources
Record Types Supported:

A (IPv4 address)
AAAA (IPv6 address)
CNAME (Canonical name)
MX (Mail exchange)
NS (Name server)
TXT (Text records)
Monitoring & Diagnostics
Diagnostic Settings
Provisioner Module: plt_diagnostic_azure.py

Purpose: Centralized logging and metrics collection.

Configuration:

diagnostic:
  logs:
    categories:
      - AuditEvent
      - AzurePolicyEvaluationDetails
    categoryGroups:
      - audit
      - allLogs
  metrics:
    categories:
      - AllMetrics
Supported Resources:

Key Vault
Storage Account
PostgreSQL
AKS
Application Gateway
Features:

Log Analytics workspace integration
Azure Monitor integration
Event Hub streaming
Storage account archival
Metric collection
Configuration Structure
Project Metadata
InfraProject:
  metadata:
    name: mes_instance_infrastructure
    version: "1.3"
  name: pasxazu
  stack: sample-dev-main
  provider: Azure
  location: northeurope
  tenantId: <tenant-id>
  subscriptionId: <subscription-id>
Tags
All resources support tagging for organization and cost tracking:

tags:
  Environment: dev
  Project: sample
  CostCenter: engineering
  ManagedBy: pulumi
Provisioner Architecture
Main Entry Point
File: main.py

Commands:

preview - Preview infrastructure changes
up - Create or update infrastructure
destroy - Destroy infrastructure resources
validate - Validate configuration
version - Display provisioner version
Execution Flow
Configuration Loading: Load YAML infrastructure specification
Resource Group Creation: Create base resource groups
Proximity Placement Group: Create PPG if enabled
Networking: Create VNet, subnets, NSG, NAT Gateway
Security: Create Key Vault, generate secrets, create SSH keys
Storage: Create storage accounts and file shares
Database: Create PostgreSQL servers and databases
Compute: Create VMs, VMSS, jump hosts
Kubernetes: Create AKS/ARO clusters and node pools
Application Services: Create Application Gateway, Redis Cache
Backup: Configure backup policies and protection
DNS: Create DNS zones and records
Monitoring: Configure diagnostic settings
Post-Processing: Create Kubernetes secrets, configure cluster access
Module Organization
plt_azure/
├── main.py                    # Entry point
├── plt_infra_creator.py       # Orchestration logic
├── plt_provisioner/           # Resource provisioners
│   ├── plt_resource_azure.py
│   ├── plt_network_azure.py
│   ├── plt_compute_azure.py
│   ├── plt_k8s_cluster_azure.py
│   ├── plt_storage_azure.py
│   ├── plt_postgres_flexible_azure.py
│   ├── plt_keyvault_azure.py
│   ├── plt_application_gw_azure.py
│   └── ...
├── plt_model/                 # Data models
├── plt_util/                  # Utility functions
└── k8s_util/                  # Kubernetes utilities
Output and Results
Generated Outputs
After successful provisioning, the tool generates comprehensive documentation in multiple formats:

1. Infrastructure JSON File
File Format: <output-name>-<timestamp>.json
Example: instance-2025-07-18-20-43-01.json

Purpose: Complete infrastructure state with all resource details in JSON format.

Contents:

Resource IDs and ARNs
Generated resource names
IP addresses and FQDNs
Network configurations
Resource dependencies
Configuration parameters
Tags and metadata
Usage:

# Used for programmatic access and automation
jq '.cluster.id' instance-2025-07-18-20-43-01.json
2. Infrastructure Markdown Documentation (SEQ)
File Format: <output-name>-<timestamp>.md
Example: instance-2025-07-18-20-43-01.md
Generator Module: plt_doc/generate_doc.py

Purpose: Human-readable infrastructure documentation with complete resource details.

Document Sections:

General Information

Project name, stack, status
Provider and location
Timestamp of generation
Resource Groups

Names and IDs
Location and tags
Networking

Virtual Networks (VNet)
Subnets with CIDR blocks
NAT Gateway configuration
Network Security Groups (NSG)
VNet Peering details
DNS Zones (Private and Public)
Compute Resources

Virtual Machines
VM Scale Sets
Jump Hosts
Image references
SSH key pairs
Kubernetes/Container

Cluster details (AKS/ARO)
Node pools configuration
Kubernetes version
API endpoint (FQDN)
Attached container registries
Persistent volumes
Application Gateway & WAF

SKU and capacity
Frontend/Backend configuration
Routing rules and listeners
WAF policy with custom and managed rules
Public IP addresses
Database

PostgreSQL Flexible Server
Version, SKU, storage
Database names
Connection details
Custom parameters
High availability configuration
Security

Azure Key Vault details
Secrets inventory (with descriptions)
RBAC roles
SSH key pairs (public keys visible)
Managed identities
Storage

Storage accounts
File shares with quotas
Backup configuration
Retention policies
SKU and redundancy settings
Cache

Redis cache configuration
SKU and capacity
Network integration
Template Engine: Jinja2 with time extensions
Templates Location: plt_azure/plt_doc/templates/

Available Templates:

seq_template.md.jinja2 - Main template
network_template.md.jinja2 - Network resources
compute_instance_template.md.jinja2 - VMs
k8s_cluster_template.md.jinja2 - Kubernetes clusters
postgres_template.md.jinja2 - PostgreSQL servers
keyvault_template.md.jinja2 - Key Vault
storage_template.md.jinja2 - Storage accounts
application_gateway_template.md.jinja2 - App Gateway
waf_template.md.jinja2 - WAF policies
cache_redis_template.md.jinja2 - Redis cache
vmscaleset_template.md.jinja2 - VM Scale Sets
jumphost_template.md.jinja2 - Jump hosts
keypair.md.jinja2 - SSH keys
addresses_template.md.jinja2 - IP addresses
3. Infrastructure PDF Documentation (Optional)
File Format: <output-name>-<timestamp>.pdf
Status: Available as optional feature

Purpose: Printable and shareable documentation of deployed infrastructure.

Features:

Professional PDF formatting
Headers and footers with date, page numbers, and headings
Complete infrastructure details from Markdown conversion
Suitable for audit, compliance, and handover documentation
PDF Generation Options:

Option A: Using mdpdf (Currently Commented in Code)
# Requires: pip install mdpdf
# Command format in generate_doc.py:
mdpdf -o "output.pdf" \
  --footer "{date},{heading},{page}" \
  --header "{date},{heading},{page}" \
  "input.md"
Option B: Manual Conversion
# Using pandoc
pandoc instance-2025-07-18-20-43-01.md \
  -o instance-2025-07-18-20-43-01.pdf \
  --pdf-engine=xelatex \
  -V geometry:margin=1in

# Using grip (GitHub-flavored markdown)
grip instance-2025-07-18-20-43-01.md --export instance-2025-07-18-20-43-01.html
wkhtmltopdf instance-2025-07-18-20-43-01.html instance-2025-07-18-20-43-01.pdf

# Using markdown-pdf (Node.js)
npm install -g markdown-pdf
markdown-pdf instance-2025-07-18-20-43-01.md
Option C: Enable PDF Generation in Code
To enable automatic PDF generation, uncomment the PDF generation code in plt_azure/plt_doc/generate_doc.py:

# Install dependency
pip install mdpdf

# Uncomment lines 25-42 in generate_doc.py:
# Convert markdown to pdf file using python package mdpdf
input_file = output_file_path
file_name = os.path.splitext(os.path.basename(output_file_path))[0]
dir_path = os.path.dirname(output_file_path)
file_path_without_ext = os.path.join(dir_path, file_name)
output_file = file_path_without_ext + '.pdf'
format = '{date},{heading},{page}'

cmd = f'mdpdf -o "{output_file}" --footer "{format}" "{input_file}" --header "{format}"'

if os.name == 'nt':  # Windows
    subprocess.run(cmd, shell=True)
else:  # Linux or other POSIX-compliant OS
    subprocess.run(cmd, shell=True, executable='/bin/bash')
logger.info(f"pdf document: {output_file}")
4. Kubernetes Configuration
File: kubeconfig (for AKS/ARO clusters)

Purpose: kubectl configuration for cluster access.

Contents:

Cluster API endpoint
Authentication credentials
Certificate authority data
Context configuration
Usage:

export KUBECONFIG=/path/to/kubeconfig
kubectl get nodes
5. Ansible Inventory (Optional)
Purpose: Inventory file for Ansible configuration management.

Contents:

Host groups
IP addresses
SSH connection details
Host variables
Output File Locations
Default Location: Current directory
Custom Location: Specify with -d, --destdir parameter

# Default output (current directory)
python -m plt_azure.main up -i infra.yaml

# Custom output directory
python -m plt_azure.main up -i infra.yaml -d /path/to/output

# Custom file name prefix
python -m plt_azure.main up -i infra.yaml -n my-infrastructure
Generated Files:

output/
├── instance-2025-07-18-20-43-01.json   # Infrastructure state
├── instance-2025-07-18-20-43-01.md     # Markdown documentation
├── instance-2025-07-18-20-43-01.pdf    # PDF documentation (optional)
└── kubeconfig                           # Kubernetes access (if cluster created)
Results Dictionary
The provisioner maintains a results dictionary with:

Resource IDs (Azure resource IDs)
Generated names (actual Azure resource names)
IP addresses (public and private)
FQDNs (fully qualified domain names)
Connection strings (database, storage)
Kubeconfig data
Secret references (Key Vault URLs)
Subnet IDs
Network Security Group IDs
Proximity placement group IDs
Sample Documentation Output
Example Markdown Structure:

# SEQ for pasxazu
Document generated at 18 Jul 2025 22:43:24 CEST

## General
>name: pasxazu
>stack: priyesh-dev-main
>status: preview
>provider: Azure
>location: germanywestcentral

## Network
>### V-Net: vnet-priyesh-dev
>cidr: 10.80.166.0/24
>### Subnets
>>#### Subnet: snet-priyesh-dev-cluster
>>cidr: 10.80.166.0/25

## Cluster
> ### Kubernetes Cluster priyesh-dev-cluster
> kubernetes version: 1.32.4
> sku_tier: Free

## Postgres
> ### Postgres pg-priyesh-dev
> version: 17
> storage_mb: 262144
> sku: Standard_D4ds_v4

## Keyvault
> ### Keyvault kvpriyeshdev
> #### Secrets
>> POSTGRES-ADMIN-PASSWORD: _value was generated_
>> STORAGE-KEY: _Storage account key_

___
**end of document**
___
Viewing and Using Documentation
Markdown Viewing:

# View in terminal
cat instance-2025-07-18-20-43-01.md | less

# View with markdown renderer
glow instance-2025-07-18-20-43-01.md

# View in VS Code
code instance-2025-07-18-20-43-01.md
JSON Querying:

# Query specific resources
jq '.cluster' instance-2025-07-18-20-43-01.json
jq '.network.subnets' instance-2025-07-18-20-43-01.json
jq '.keyvault.secrets[].name' instance-2025-07-18-20-43-01.json
PDF Sharing:

Email to stakeholders
Upload to documentation portal
Include in compliance audits
Attach to change requests
Authentication & Credentials
Required Environment Variables
export AZURE_TENANT_ID='<tenant-id>'
export AZURE_CLIENT_ID='<client-id>'
export AZURE_CLIENT_SECRET='<client-secret>'
export PULUMI_CONFIG_PASSPHRASE='<passphrase>'
export PROJECT_CRYPTO_KEY='<encryption-key>'
Remote State Backend
export RG_NAME="<resource-group>"
export AZURE_STORAGE_ACCOUNT="<storage-account>"
export AZURE_STORAGE_KEY="<storage-key>"
pulumi login --cloud-url azblob://<container-path>
Best Practices
Naming Conventions
Resource Group: rg-<project>-<environment>-<purpose>
VNet: vnet-<project>-<environment>
Subnet: snet-<project>-<environment>-<purpose>
Key Vault: kv<project><environment> (max 24 chars)
Storage: st<project><environment> (lowercase, no hyphens)
Network Design
Use /25 or larger CIDR for VNets
Reserve separate subnets for cluster, database, application gateway
Enable service delegation where required
Use NAT Gateway for outbound connectivity
Security
Use private endpoints for PaaS services
Store all secrets in Key Vault
Enable RBAC for Key Vault
Use managed identities instead of service principals where possible
Enable soft delete and purge protection on Key Vault
High Availability
Use availability zones (minimum 2 zones)
Enable zone redundancy for databases
Configure auto-scaling for AKS node pools
Implement backup policies with appropriate retention
Cost Optimization
Use appropriate SKUs (Basic, Standard, Premium)
Enable auto-scaling with min/max node counts
Use spot instances for non-critical workloads
Implement proper tagging for cost allocation
Sample Configuration Files
Sample configurations are available in the sample_file/ directory:

sample_main_infra.yaml - Complete infrastructure example
sample_devops_infra.yaml - DevOps-specific infrastructure
provisioner.yaml - Provisioner configuration
Troubleshooting
Common Issues
Key Vault Name Conflicts: Key Vault names must be globally unique and <= 24 characters
Subnet Size: Ensure subnets are large enough for required resources
IP Exhaustion: Monitor subnet usage and plan for growth
Private Endpoint DNS: Verify private DNS zone configuration
RBAC Delays: Role assignments may take 5-10 minutes to propagate
Logs
Provisioner logs: instance.log (configurable via -l flag)
Pulumi logs: ~/.pulumi/logs/
Azure activity logs: Azure Portal > Monitor > Activity Log
Version Information
Provisioner Version: Check with python -m plt_azure.main version Pulumi Version: Specified in project dependencies Supported Azure API Versions: Uses pulumi-azure-native latest

Support and Documentation
README: README.md
Integration Tests: Integration_tests_README.md
Unit Tests: plt_azure/unit_test/
Packer Images: packer/ directory
Docker Container
Dockerfile
File: Dockerfile

Purpose: Multi-stage Docker container for running the Azure provisioner in a containerized environment.

Base Images
Builder Stage: bitnami/minideb:latest
Runtime Stage: ubuntu:noble
Installed Tools & Versions
Build Arguments (Configurable):

PULUMI_VERSION=3.181.0
KUBECTL_VERSION=v1.32.4
YQ_VERSION=v4.45.4
PULUMI_AZURE_VERSION=6.24.0
PULUMI_AZURE_NATIVE_VERSION=2.72.0
PULUMI_KUBERNETES_VERSION=4.23.0
PULUMI_RANDOM_VERSION=4.18.2
PULUMI_TLS_VERSION=5.2.0
Core Tools:

Pulumi: v3.181.0 - Infrastructure as Code engine
Kubectl: v1.32.4 - Kubernetes command-line tool
Helm: Latest stable - Kubernetes package manager
Docker: Latest CE - Container runtime
Azure CLI: Latest - Azure command-line interface
yq: v4.45.4 - YAML processor
uv: v0.7.13 - Fast Python package installer
Python Environment:

Python 3.x with pip
Virtual environment support
UV package manager for fast dependency installation
Pulumi Plugins Pre-installed
azure: v6.24.0
azure-native: v2.72.0
kubernetes: v4.23.0
random: v4.18.2
tls: v5.2.0
Certificate Management
Custom corporate certificate (koerber.crt) is installed and trusted in both builder and runtime stages.

Environment Variables
PATH: Includes /apps/pulumi for Pulumi CLI access
ARM_SKIP_PROVIDER_REGISTRATION=true: Azure provider optimization
Container Structure
/apps/
├── pulumi/              # Pulumi binaries
├── plt_azure/           # Provisioner Python modules
├── pyproject.toml       # Python project configuration
├── uv.lock              # Locked dependencies
├── version.yaml         # Provisioner version
└── README.md
Entry Point
CMD cd /apps/ && uv run azure-provisioner version && /bin/bash
Usage
# Build the image
docker build -t azure-provisioner:latest .

# Run the container
docker run -it \
  -e AZURE_TENANT_ID=$AZURE_TENANT_ID \
  -e AZURE_CLIENT_ID=$AZURE_CLIENT_ID \
  -e AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET \
  -e PULUMI_CONFIG_PASSPHRASE=$PULUMI_CONFIG_PASSPHRASE \
  -e PROJECT_CRYPTO_KEY=$PROJECT_CRYPTO_KEY \
  -v $(pwd)/output:/apps/output \
  azure-provisioner:latest
CI/CD Workflows
1. Build and Push Provisioner Docker Image
File: .github/workflows/build-provisioner-image.yaml

Trigger:

Manual dispatch with custom image tag
Automatic on push to main branch
Inputs:

ImageTag: Tag applied to container image (default: latest)
Workflow Steps:

Checkout repository
Login to Azure Container Registry (ACR)
Copy provisioner files to build context
Build Docker image with two tags:
User-specified tag (e.g., latest)
Build-specific tag (e.g., build-12345)
Push image to ACR: pasxregistry.azurecr.io/platform/com.koerber-pharma.plt.provisioner.azure
Registry: pasxregistry.azurecr.io

Secrets Required:

PASXREGISTRY_USERNAME: ACR username
PASXREGISTRY_PASSWORD: ACR password
2. Lint and Test
File: .github/workflows/lint-and-test.yaml

Trigger:

Push to any branch
Pull requests to any branch
Workflow Steps:

Checkout code
Install UV package manager (v0.7.8)
Run Ruff linting on plt_azure/ directory
Execute unit tests with pytest:
Generate JUnit XML test results
Generate coverage reports (XML, HTML, terminal)
Branch coverage enabled
Upload coverage report as artifact
Upload test results as artifact
Linting:

Tool: Ruff - Fast Python linter and formatter
Target: All files in plt_azure/ directory
Testing:

Framework: pytest
Coverage tool: pytest-cov
Configuration: plt_azure/unit_test/.coveragerc
Artifacts: htmlcov/, test-*.xml
3. Build Ubuntu VM Image
File: .github/workflows/build-ubuntu-vmi.yaml

Trigger: Manual dispatch only

Inputs:

gallery_name: Azure Compute Gallery name (default: cg_devops_agent_images)
resource_group_name: Resource group for gallery (default: rg-kph-azure-saas-packer)
image_name: Image definition name (default: vmi-kphs-ubuntu-2404)
image_version: Semantic version for the image
Purpose: Build custom Ubuntu 24.04 VM images with pre-installed tools for DevOps agents.

Workflow Steps:

Install Packer (latest version)
Azure login with service principal
Initialize Packer with required plugins
Validate Packer template
Build VM image with custom tooling
Upload to Azure Compute Gallery
Secrets Required:

ARM_GRESOURCES_SPN_CLIENT_ID
ARM_GRESOURCES_SPN_CLIENT_SECRET
ARM_GRESOURCES_SPN_TENANT_ID
ARM_GRESOURCES_NONPROD_SUBSCRIPTION_ID
Packer VM Image Builder
Packer Configuration
File: packer/packer.pkr.hcl

Purpose: Build customized Ubuntu VM images for Azure with pre-installed DevOps tools.

Base Image:

Publisher: Canonical
Offer: ubuntu-24_04-lts
SKU: server
OS Type: Linux
Build Configuration:

VM Size: Standard_B1s
Replication Regions: Germany West Central
Destination: Azure Compute Gallery (Shared Image Gallery)
Installation Script
File: packer/install.sh

Pre-installed Tools:

Tool	Version	Purpose
Azure CLI	2.74.0	Azure management
Helm	v3.17.3	Kubernetes package manager
kubectl	v1.33.0	Kubernetes CLI
k9s	v0.50.6	Kubernetes TUI
yq	v4.54.4	YAML processor
DBeaver	25.1.0	Database management
PostgreSQL Client	16	Database client
UV	0.7.12	Python package manager
Docker	Latest CE	Container runtime
Python 3	Latest	Programming language
Git	Latest	Version control
JQ	Latest	JSON processor
Build Tools:

gcc, make, clang, patch
libcups2-dev (CUPS development libraries)
build-essential
Package Manager:

APT with automatic retry mechanism (up to 5 attempts)
Handles network failures gracefully
Setup Helper Scripts
1. Setup Python Environment
File: pulumi-setup-scripts/setup_python.sh

Purpose: Initialize Python virtual environment and install dependencies.

Actions:

Activates virtual environment from ../venv/Scripts/
Installs requirements from plt_azure/requirements.txt
Installs Ruff linter
Usage:

cd pulumi-setup-scripts
./setup_python.sh
2. Setup Credentials
File: pulumi-setup-scripts/setup_credentials_template.sh

Purpose: Template for configuring Azure and Pulumi credentials.

Environment Variables:

PULUMI_CONFIG_PASSPHRASE    # Pulumi state encryption key
AZURE_TENANT_ID             # Azure AD tenant ID
AZURE_CLIENT_ID             # Service principal client ID
AZURE_CLIENT_SECRET         # Service principal secret
PROJECT_CRYPTO_KEY          # Project-specific encryption key
Actions:

Exports required environment variables
Performs Azure CLI login with service principal
Usage:

# Copy template and customize
cp setup_credentials_template.sh setup_credentials.sh
# Edit with your credentials
# Source the file
source setup_credentials.sh
3. Pulumi Backend Login
File: pulumi-setup-scripts/pulumi_login_backend_template.sh

Purpose: Configure Pulumi to use Azure Blob Storage as state backend.

Configuration:

RG_NAME                     # Resource group containing storage account
AZURE_STORAGE_ACCOUNT       # Storage account name
AZURE_STORAGE_KEY           # Storage account access key
Actions:

Exports storage configuration
Logs into Pulumi backend: azblob://container-path
Performs interactive Azure CLI login
Usage:

# Copy template and customize
cp pulumi_login_backend_template.sh pulumi_login_backend.sh
# Edit with your storage details
# Source the file
source pulumi_login_backend.sh
4. Set Storage Backend
File: pulumi-setup-scripts/set_storage_backend.sh

Purpose: Create and configure Azure Storage backend for Pulumi state.

Configuration:

RG_NAME="pulumi-storage"
AZURE_LOCATION="germanywestcentral"
STORAGE_ACC_NAME="dfopulumi1234"
STORAGE_SKU="STANDARD_LRS"
STORAGE_CONTAINER_NAME="aks-state"
Actions:

Defines storage account configuration
Retrieves storage account access key
Exports variables for Pulumi backend usage
5. Role Assignment
File: pulumi-setup-scripts/role-assignment.sh

Purpose: Example script for assigning Azure RBAC roles.

Example Usage:

az role assignment create \
  --assignee "<service-principal-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<rg-name>"
Python Dependencies
Project Configuration
File: pyproject.toml

Project Details:

Name: azure-provisioner
Version: 1.1.0
Python Requirement: >=3.12
Build System: Hatchling
Core Dependencies
Pulumi & Cloud Providers
pulumi
pulumi-azure-native==2.72.0
pulumi-kubernetes
pulumi-random
pulumi-tls
Azure SDK
azure-identity              # Authentication
azure-keyvault              # Key Vault access
azure-mgmt-compute          # VM management
azure-mgmt-core             # Core management
azure-mgmt-keyvault         # Key Vault management
azure-mgmt-authorization    # RBAC management
azure-mgmt-network          # Network management
azure-mgmt-privatedns       # Private DNS management
azure-mgmt-rdbms            # Database management
azure-mgmt-containerservice # AKS management
azure-mgmt-recoveryservicesbackup  # Backup management
azure-mgmt-resource         # Resource management
azure-mgmt-dns              # DNS management
Kubernetes
kubernetes                  # Python Kubernetes client
Utilities
loguru                      # Logging
jinja2                      # Template engine
jinja2-time                 # Time extensions for Jinja2
cryptography                # Cryptographic operations
pyopenssl                   # SSL/TLS support
pytz                        # Timezone handling
rich-argparse               # Enhanced CLI argument parsing
jsonpickle                  # JSON serialization
Validation & Schema
pydantic                    # Data validation
pydantic[email]             # Email validation
openapi-schema-validator    # OpenAPI schema validation
openapi_spec_validator      # OpenAPI spec validation
Development Tools
ruff                        # Linter and formatter
pytest                      # Testing framework
pytest-cov                  # Coverage plugin
Tool Configuration
Ruff Settings
[tool.ruff]
line-length = 180

[tool.ruff.lint]
select = ["E", "I", "N"]    # Error, Import, Naming conventions
ignore = ["E501", "N815"]   # Line too long, Mixed case variable

[tool.ruff.format]
quote-style = "double"
docstring-code-format = true
UV Package Manager
[tool.uv]
native-tls = true
allow-insecure-host = [
    "pypi.org",
    "pypi.python.org",
    "files.pythonhosted.org"
]
Entry Point
[project.scripts]
azure-provisioner = "plt_azure.main:provision_infrastructure"
Usage:

# Install with UV
uv sync --locked

# Run provisioner
uv run azure-provisioner up -i infra.yaml

# Or after installation
azure-provisioner up -i infra.yaml
Version Management
Version File
File: version.yaml

version: Azure-plt-provisioner-1.0.0
Purpose: Single source of truth for provisioner version information.

Usage: Referenced in code, Docker builds, and documentation generation.

Development Workflow
Local Development Setup
Clone Repository:

git clone <repository-url>
cd azure-provisioner
Install UV:

curl -LsSf https://astral.sh/uv/install.sh | sh
Setup Python Environment:

uv sync --locked
Configure Credentials:

cp pulumi-setup-scripts/setup_credentials_template.sh setup_credentials.sh
# Edit setup_credentials.sh with your credentials
source setup_credentials.sh
Configure Pulumi Backend:

cp pulumi-setup-scripts/pulumi_login_backend_template.sh pulumi_login_backend.sh
# Edit pulumi_login_backend.sh with your storage details
source pulumi_login_backend.sh
Run Tests:

uv run pytest -v --cov=plt_azure
Run Linter:

uv run ruff check plt_azure/
Run Provisioner:

uv run azure-provisioner up -i sample_file/sample_main_infra.yaml
Container Development
Build Docker Image:

docker build -t azure-provisioner:dev .
Run Container:

docker run -it \
  -e AZURE_TENANT_ID=$AZURE_TENANT_ID \
  -e AZURE_CLIENT_ID=$AZURE_CLIENT_ID \
  -e AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET \
  -e PULUMI_CONFIG_PASSPHRASE=$PULUMI_CONFIG_PASSPHRASE \
  -e PROJECT_CRYPTO_KEY=$PROJECT_CRYPTO_KEY \
  -v $(pwd)/output:/apps/output \
  -v $(pwd)/sample_file:/apps/sample_file \
  azure-provisioner:dev
Test Inside Container:

cd /apps
uv run azure-provisioner version
uv run azure-provisioner validate -i sample_file/sample_main_infra.yaml
CI/CD Integration
Continuous Integration:

All pushes trigger linting and testing
Pull requests must pass all checks
Coverage reports are generated and stored
Continuous Deployment:

Pushes to main automatically build and push Docker images
Tagged with both latest and build-specific tags
Images stored in ACR for deployment
Security Considerations
Secrets Management
Never commit credentials to repository
Use template files for credential scripts (add to .gitignore)
Store secrets in Azure Key Vault
Use managed identities where possible
Certificate Management
Corporate certificates included in Docker image
Certificates trusted in both build and runtime stages
Enables secure communication with internal resources
Container Security
Multi-stage builds minimize attack surface
Minimal runtime image based on Ubuntu Noble
Security updates applied during build
Non-root user execution recommended
RBAC & Permissions
Service principals follow principle of least privilege
Role assignments scoped to specific resource groups
Audit logs enabled for all operations
Troubleshooting
Docker Build Issues
Problem: Certificate verification failures

Solution: Ensure koerber.crt is in certificate/ directory
Problem: Plugin download failures

Solution: Check network connectivity and Pulumi plugin versions
CI/CD Issues
Problem: ACR authentication failures

Solution: Verify PASXREGISTRY_USERNAME and PASXREGISTRY_PASSWORD secrets
Problem: Test failures in CI

Solution: Check pytest output in artifacts, review coverage report
Development Issues
Problem: UV installation failures

Solution: Clear UV cache
rm -rf ~/.cache/uv
uv sync --locked
Problem: Pulumi backend connection issues

Solution: Verify storage account access
az storage container list --account-name $AZURE_STORAGE_ACCOUNT
