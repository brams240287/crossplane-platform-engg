# Quick Setup: Corporate CA in Docker Image

## You have 2 options to get the certificate:

### Option 1: Copy from current container (Recommended)

```bash
# Inside your current dev container, run:
sudo cp /etc/ssl/certs/ca-certificates.crt .devcontainer/corporate-ca.crt
```

### Option 2: Extract from TLS connection

```bash
# Prefer extracting from a host that fails for you (behind corporate HTTPS inspection).
# Common ones in this repo/devcontainer:
#   - dl.k8s.io (kubectl)
#   - download.docker.com (docker CLI repo)
#   - get.helm.sh (helm)
./scripts/extract-corporate-ca.sh dl.k8s.io
```

### Option 3: Get from IT department

Ask your IT team for the corporate root CA certificate and save it as:
`.devcontainer/corporate-ca.crt`

## After you have the certificate file:

1. **Verify it exists**:

   ```bash
   ls -lh .devcontainer/corporate-ca.crt
   ```

2. **Rebuild the dev container**:
   - Press `F1` in VS Code
   - Type: `Dev Containers: Rebuild Container`
   - Press Enter

3. **After rebuild, verify**:

   ```bash
   # Check CA is installed
   ls -l /usr/local/share/ca-certificates/corporate-ca.crt

   # Test HTTPS
   curl -v https://xpkg.upbound.io 2>&1 | grep "SSL certificate verify"
   ```

4. **Install Crossplane and providers**:

   ```bash
   ./scripts/install-crossplane.sh
   ./scripts/install-providers.sh

   # Check providers
   kubectl get providers
   ```

## That's it!

Your Dockerfile is already configured to install the CA certificate. You just need to:

1. Get the certificate file
2. Rebuild the container
3. Everything will work!
