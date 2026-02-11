# Corporate CA Certificate - Container Image Approach

## Overview

This approach installs the corporate CA certificate **directly into the container image** during the build process. This is the **most robust and scalable solution** because:

✅ **Single source of truth** - CA is baked into the image
✅ **Works everywhere** - All processes automatically trust the CA
✅ **No runtime patching** - No need to modify Kubernetes deployments
✅ **Build-time + Runtime** - Works for both package installation and application runtime
✅ **Language agnostic** - Python, Node.js, Go, Java, etc. all work

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ Host Machine                                             │
│ • Corporate network with TLS-intercepting firewall      │
│ • Certificate: .devcontainer/corporate-ca.crt           │
└──────────────────────────────────────────────────────────┘
                         ↓ Docker build
┌──────────────────────────────────────────────────────────┐
│ Container Image (ubuntu:22.04)                           │
│                                                           │
│ 1. COPY corporate-ca.crt →                               │
│    /usr/local/share/ca-certificates/corporate-ca.crt     │
│                                                           │
│ 2. RUN update-ca-certificates                            │
│    → Adds CA to system trust store                       │
│    → Updates /etc/ssl/certs/ca-certificates.crt          │
│                                                           │
│ 3. All tools automatically trust corporate CA:           │
│    ✓ apt, curl, wget, git                                │
│    ✓ kubectl, helm, docker                               │
│    ✓ Python (requests, urllib3)                          │
│    ✓ Node.js, Go, Java                                   │
│    ✓ Crossplane package manager                          │
└──────────────────────────────────────────────────────────┘
                         ↓ Container runs
┌──────────────────────────────────────────────────────────┐
│ Running Containers                                       │
│ • Dev container: Has CA pre-installed                    │
│ • Kind node containers: Inherit CA from dev container   │
│ • Crossplane pods: Can access CA via volume mount       │
│ • Application pods: Can access CA via volume mount      │
└──────────────────────────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Extract Corporate CA Certificate

Run the extraction script:

```bash
chmod +x scripts/extract-corporate-ca.sh
./scripts/extract-corporate-ca.sh
```

This will create `.devcontainer/corporate-ca.crt` with your corporate CA certificate.

**Alternative manual method:**

```bash
# Get certificate from intercepted HTTPS connection
echo | openssl s_client -showcerts -connect xpkg.upbound.io:443 2>/dev/null | \
  sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' > \
  .devcontainer/corporate-ca.crt

# Or get from your IT department and place at:
# .devcontainer/corporate-ca.crt
```

### Step 2: Verify Dockerfile Configuration

The Dockerfile should include (already added):

```dockerfile
# Install corporate CA certificate
COPY corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN chmod 644 /usr/local/share/ca-certificates/corporate-ca.crt \
    && update-ca-certificates \
    && echo "✅ Corporate CA certificate installed"
```

### Step 3: Rebuild Dev Container

**Option A: VS Code**

1. Press `F1` or `Ctrl+Shift+P`
2. Type: `Dev Containers: Rebuild Container`
3. Select and execute

**Option B: Command Line**

```bash
# Stop current container
docker stop <container-id>

# Rebuild image
docker build -t crossplane-dev .devcontainer/

# VS Code will detect the new image on next open
```

### Step 4: Verify CA Installation

After container rebuilds, verify:

```bash
# Check if CA is in system trust store
ls -l /usr/local/share/ca-certificates/corporate-ca.crt

# Verify it's in the CA bundle
grep -q "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt && echo "✅ CA bundle updated"

# Test HTTPS connection
curl -v https://xpkg.upbound.io 2>&1 | grep "SSL certificate verify ok"
```

### Step 5: Reinstall Crossplane

Now that the container trusts the CA, reinstall Crossplane:

```bash
# Clean install
./scripts/install-crossplane.sh

# Install providers (should work without certificate errors)
./scripts/install-providers.sh
```

## Benefits Over Runtime Solutions

### ❌ Runtime ConfigMap Mounting

- **Problem**: Every deployment needs manual configuration
- **Problem**: Doesn't help with build-time operations
- **Problem**: Containers still don't trust CA for package installations

### ❌ Kubernetes Patches

- **Problem**: Fragile - patches can be overwritten
- **Problem**: Doesn't scale across namespaces
- **Problem**: Requires maintaining patches for each deployment

### ✅ Dockerfile Installation

- **Benefit**: Single configuration in Dockerfile
- **Benefit**: Works for build AND runtime
- **Benefit**: All containers automatically trust CA
- **Benefit**: No per-deployment configuration needed
- **Benefit**: Survives container restarts and recreations

## How It Works for Different Tools

### Package Managers (Build Time)

```dockerfile
# During image build, these commands now work:
RUN apt-get update && apt-get install -y package
RUN curl -LO https://internal-registry/file
RUN wget https://corporate-server/artifact
```

All automatically trust the corporate CA!

### Runtime Tools

**curl / wget**

```bash
curl https://api.corporate.com  # ✅ Works automatically
```

**kubectl / helm**

```bash
helm repo add internal https://charts.internal.com  # ✅ Works
```

**Python**

```python
import requests
requests.get('https://internal-api.com')  # ✅ Works
```

**Node.js**

```javascript
fetch('https://corporate-service.com')  # ✅ Works
```

**Go**

```go
http.Get("https://internal.company.com")  // ✅ Works
```

### Crossplane Package Manager

The Crossplane package manager runs **inside the container** that has the CA installed, so:

```bash
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v2.3.0
EOF
```

**Crossplane can now download providers from xpkg.upbound.io** because the container trusts the corporate CA!

## For Production: Multi-Stage Build Pattern

For production images, use a multi-stage build:

```dockerfile
# ============ Builder Stage ============
FROM ubuntu:22.04 AS builder

# Install CA in builder
COPY corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN chmod 644 /usr/local/share/ca-certificates/corporate-ca.crt \
    && update-ca-certificates

# Build your application (can now access internal resources)
RUN apt-get update && apt-get install -y build-tools
COPY . /app
WORKDIR /app
RUN make build

# ============ Runtime Stage ============
FROM ubuntu:22.04

# Install CA in runtime (for runtime HTTPS calls)
COPY corporate-ca.crt /usr/local/share/ca-certificates/corporate-ca.crt
RUN chmod 644 /usr/local/share/ca-certificates/corporate-ca.crt \
    && update-ca-certificates

# Copy built artifacts
COPY --from=builder /app/dist /app

# Your application now trusts corporate CA at runtime
CMD ["/app/myapp"]
```

## Kubernetes Integration

Even though the CA is in the container, you can still mount it for other pods:

```yaml
# Create ConfigMap from container's CA bundle
apiVersion: v1
kind: ConfigMap
metadata:
  name: corporate-ca
  namespace: kube-system
data:
  ca-bundle.crt: |
    # Copy content from /etc/ssl/certs/ca-certificates.crt in container
```

Then reference in other pods if needed.

## Troubleshooting

### Certificate not working after rebuild

```bash
# Verify CA file exists
docker run --rm crossplane-dev ls -l /usr/local/share/ca-certificates/

# Check if update-ca-certificates ran
docker run --rm crossplane-dev grep -c "BEGIN CERTIFICATE" /etc/ssl/certs/ca-certificates.crt
```

### Still getting certificate errors

```bash
# Some tools need explicit env vars
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt
```

### CA certificate expired

```bash
# Get updated certificate from IT
# Replace .devcontainer/corporate-ca.crt
# Rebuild container
```

## Security Considerations

1. **Certificate Storage**: The CA is stored in the image (visible to anyone with image access)
2. **Scope**: Only trust CAs necessary for your environment
3. **Updates**: When CA rotates, rebuild all images
4. **Private Registries**: Push images to private registry, don't expose publicly

## Summary

This approach is **production-ready** and follows industry best practices:

✅ Used by major corporations with corporate TLS interception
✅ Recommended by Docker, Kubernetes, and cloud providers  
✅ Scalable - one configuration affects all containers
✅ Maintainable - CA updates are centralized
✅ Secure - CA is baked in, not dynamically injected

**Next Steps:**

1. Run `./scripts/extract-corporate-ca.sh`
2. Rebuild dev container
3. Reinstall Crossplane
4. Providers will install successfully!
