# Network Compositions

This directory contains Crossplane compositions for Azure networking resources.

## Available Compositions

### xrd-network.yaml
Defines the `XAzureNetwork` composite resource for creating virtual networks with subnets, NSGs, and NAT gateways.

### composition-network-dev.yaml
Development environment network composition with:
- Basic SKUs
- Single availability zone
- Standard firewall rules

### composition-network-prod.yaml
Production environment network composition with:
- Premium SKUs
- Multiple availability zones
- Enhanced security rules
- DDoS protection

## Usage

```yaml
apiVersion: platform.example.com/v1alpha1
kind: AzureNetwork
metadata:
  name: dev-network
  namespace: infra-dev
spec:
  parameters:
    region: northeurope
    resourceGroup: rg-dev-main
    vnetName: vnet-dev
    addressSpace:
      - "10.0.0.0/16"
    subnets:
      - name: snet-aks
        addressPrefix: "10.0.0.0/24"
      - name: snet-db
        addressPrefix: "10.0.1.0/24"
```
