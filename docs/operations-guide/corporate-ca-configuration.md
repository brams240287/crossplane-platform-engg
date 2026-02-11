# Corporate CA Certificate Configuration

## Overview

This cluster is configured with a **corporate CA certificate** to handle TLS interception by corporate firewalls. The CA certificate is available cluster-wide for all applications.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Kind Cluster Nodes                                          │
│ • CA installed in: /usr/local/share/ca-certificates/        │
│ • System trust store updated                                │
│ • All node-level operations trust corporate CA              │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes ConfigMap: kube-system/corporate-ca-bundle       │
│ • Contains: ca-bundle.crt (PEM format)                      │
│ • Accessible from any namespace                             │
└─────────────────────────────────────────────────────────────┘
                              ↓
    ┌─────────────────────────┴─────────────────────────┐
    │                                                     │
┌───▼───────────────────┐              ┌─────────────────▼─────┐
│ Crossplane Pods       │              │ Application Pods      │
│ • Core deployment     │              │ • Mount CA ConfigMap  │
│ • Provider pods       │              │ • Set SSL_CERT_FILE   │
│   (via RuntimeConfig) │              │ • Trust corporate CA  │
└───────────────────────┘              └───────────────────────┘
```

## Setup

Run the cluster-wide CA setup script:

```bash
./scripts/setup-cluster-wide-ca.sh
```

This will:

1. Extract corporate CA certificate
2. Install CA on all Kind cluster nodes
3. Create ConfigMap `corporate-ca-bundle` in `kube-system` namespace
4. Configure Crossplane core deployment
5. Configure Crossplane provider pods via DeploymentRuntimeConfig
6. Update provider manifests

## Using the CA in Your Applications

### Method 1: Via Deployment Manifest

Add to your deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      volumes:
        - name: ca-bundle
          configMap:
            name: corporate-ca-bundle
            namespace: kube-system # Cross-namespace reference
      containers:
        - name: myapp
          image: myapp:latest
          volumeMounts:
            - name: ca-bundle
              mountPath: /etc/ssl/certs/ca-bundle.crt
              subPath: ca-bundle.crt
              readOnly: true
          env:
            - name: SSL_CERT_FILE
              value: /etc/ssl/certs/ca-bundle.crt
            - name: REQUESTS_CA_BUNDLE # Python requests library
              value: /etc/ssl/certs/ca-bundle.crt
            - name: CURL_CA_BUNDLE # curl
              value: /etc/ssl/certs/ca-bundle.crt
            - name: NODE_EXTRA_CA_CERTS # Node.js
              value: /etc/ssl/certs/ca-bundle.crt
```

### Method 2: Via Helm Values

For Helm charts:

```yaml
# values.yaml
volumes:
  - name: ca-bundle
    configMap:
      name: corporate-ca-bundle

volumeMounts:
  - name: ca-bundle
    mountPath: /etc/ssl/certs/ca-bundle.crt
    subPath: ca-bundle.crt
    readOnly: true

env:
  SSL_CERT_FILE: /etc/ssl/certs/ca-bundle.crt
  REQUESTS_CA_BUNDLE: /etc/ssl/certs/ca-bundle.crt
```

### Method 3: Via Init Container (Copy to emptyDir)

For applications that need writable CA path:

```yaml
spec:
  initContainers:
    - name: setup-ca
      image: busybox
      command:
        - sh
        - -c
        - cp /ca-source/ca-bundle.crt /ca-dest/ca-bundle.crt
      volumeMounts:
        - name: ca-source
          mountPath: /ca-source
        - name: ca-dest
          mountPath: /ca-dest
  containers:
    - name: myapp
      volumeMounts:
        - name: ca-dest
          mountPath: /etc/ssl/certs
      env:
        - name: SSL_CERT_FILE
          value: /etc/ssl/certs/ca-bundle.crt
  volumes:
    - name: ca-source
      configMap:
        name: corporate-ca-bundle
    - name: ca-dest
      emptyDir: {}
```

## Language-Specific Configuration

### Python (requests, urllib3)

```python
import os
os.environ['REQUESTS_CA_BUNDLE'] = '/etc/ssl/certs/ca-bundle.crt'

# Or in code:
import requests
requests.get('https://example.com', verify='/etc/ssl/certs/ca-bundle.crt')
```

### Node.js

```bash
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-bundle.crt
```

### Go

```go
import (
    "crypto/x509"
    "io/ioutil"
)

caCert, _ := ioutil.ReadFile("/etc/ssl/certs/ca-bundle.crt")
caCertPool := x509.NewCertPool()
caCertPool.AppendCertsFromPEM(caCert)

tlsConfig := &tls.Config{
    RootCAs: caCertPool,
}
```

### Java

```bash
# Import CA into Java truststore
keytool -import -trustcacerts -file /etc/ssl/certs/ca-bundle.crt \
  -alias corporate-ca -keystore $JAVA_HOME/lib/security/cacerts
```

### curl

```bash
curl --cacert /etc/ssl/certs/ca-bundle.crt https://example.com
# Or via environment:
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-bundle.crt
```

## Verification

Check if CA is working:

```bash
# In a pod with the CA mounted:
kubectl exec -it <pod-name> -- curl https://xpkg.upbound.io -v

# Should show: SSL certificate verify ok
```

## Troubleshooting

### Certificate verification failed

Check if CA is properly mounted:

```bash
kubectl exec -it <pod-name> -- cat /etc/ssl/certs/ca-bundle.crt
```

### Environment variable not set

Verify env vars:

```bash
kubectl exec -it <pod-name> -- env | grep -i cert
```

### ConfigMap not found

Ensure ConfigMap exists:

```bash
kubectl get configmap corporate-ca-bundle -n kube-system
```

## Crossplane-Specific Configuration

Crossplane providers automatically use the CA through **DeploymentRuntimeConfig**:

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: default-with-ca
spec:
  deploymentTemplate:
    spec:
      template:
        spec:
          volumes:
            - name: ca-bundle
              configMap:
                name: corporate-ca-bundle
          containers:
            - name: package-runtime
              volumeMounts:
                - name: ca-bundle
                  mountPath: /etc/ssl/certs/ca-bundle.crt
                  subPath: ca-bundle.crt
              env:
                - name: SSL_CERT_FILE
                  value: /etc/ssl/certs/ca-bundle.crt
```

Reference in Provider:

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure-network
spec:
  package: xpkg.upbound.io/upbound/provider-azure-network:v2.3.0
  runtimeConfigRef:
    name: default-with-ca # ← References the RuntimeConfig
```

## Security Considerations

1. **CA Certificate Storage**: The CA is stored in a ConfigMap (not encrypted)
2. **Trust Scope**: Only trust corporate CAs necessary for your environment
3. **Rotation**: When CA certificate is rotated, update ConfigMap and restart pods
4. **Production**: Consider using cert-manager or external secrets management

## Updating the CA Certificate

When corporate CA changes:

```bash
# 1. Update ConfigMap
kubectl create configmap corporate-ca-bundle \
  --from-file=ca-bundle.crt=/path/to/new-ca.crt \
  -n kube-system \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Restart Crossplane
kubectl rollout restart deployment/crossplane -n crossplane-system

# 3. Restart providers (they'll pick up new CA automatically)
kubectl delete pods -n crossplane-system -l pkg.crossplane.io/provider

# 4. Restart your application pods
kubectl rollout restart deployment/<your-app>
```

## Alternative: Mutating Admission Webhook

For fully automated CA injection, consider using a mutating admission webhook:

- Automatically injects CA ConfigMap into all pods
- No manual configuration per deployment
- Examples: cert-manager's ca-injector, custom webhook

## References

- [Crossplane DeploymentRuntimeConfig](https://docs.crossplane.io/latest/concepts/packages/#runtime-configuration)
- [Kubernetes ConfigMap volumes](https://kubernetes.io/docs/concepts/configuration/configmap/#using-configmaps-as-volumes)
- [Kind extra mounts](https://kind.sigs.k8s.io/docs/user/configuration/#extra-mounts)
