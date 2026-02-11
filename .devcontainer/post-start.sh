#!/bin/bash
# This script runs every time the container starts (including after rebuilds)

echo "🔧 Post-start configuration..."

# Fix kubeconfig IP if Kind cluster exists
CLUSTER_NAME="${CLUSTER_NAME:-crossplane-dev}"
if docker ps --format '{{.Names}}' | grep -q "${CLUSTER_NAME}-control-plane"; then
  echo "🔧 Fixing kubeconfig for Kind cluster..."

  # Ensure this devcontainer can reach the kind network IPs (e.g. 172.19.0.0/16)
  SELF_ID="$(hostname)"
  if docker network inspect kind >/dev/null 2>&1; then
    if docker inspect "$SELF_ID" >/dev/null 2>&1; then
      if ! docker inspect "$SELF_ID" --format '{{json .NetworkSettings.Networks}}' | grep -q '"kind"'; then
        echo "🔧 Connecting devcontainer to Docker network: kind"
        docker network connect kind "$SELF_ID" >/dev/null 2>&1 || true
      fi
    fi
  fi
  
  CONTROL_PLANE_IP=$(docker inspect ${CLUSTER_NAME}-control-plane --format='{{.NetworkSettings.Networks.kind.IPAddress}}' 2>/dev/null || echo "")
  if [ -z "$CONTROL_PLANE_IP" ]; then
    CONTROL_PLANE_IP=$(docker inspect ${CLUSTER_NAME}-control-plane --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "")
  fi

  # Collect kubeconfig files to update:
  # - ~/.kube/config (default)
  # - $KUBECONFIG entries (if set)
  # - workspace .kubeconfig (commonly used by repo scripts/docs)
  KUBECONFIG_FILES=()
  [ -f "$HOME/.kube/config" ] && KUBECONFIG_FILES+=("$HOME/.kube/config")

  if [ -n "${KUBECONFIG:-}" ]; then
    IFS=':' read -r -a _kc_parts <<< "$KUBECONFIG"
    for _p in "${_kc_parts[@]}"; do
      [ -n "${_p:-}" ] && [ -f "$_p" ] && KUBECONFIG_FILES+=("$_p")
    done
  fi

  [ -f /home/vscode/workspace/.kubeconfig ] && KUBECONFIG_FILES+=(/home/vscode/workspace/.kubeconfig)

  if [ -n "$CONTROL_PLANE_IP" ] && [ ${#KUBECONFIG_FILES[@]} -gt 0 ]; then
    for cfg in "${KUBECONFIG_FILES[@]}"; do
      # Fix any server address pattern
      sed -i "s|server: https://.*:6443|server: https://${CONTROL_PLANE_IP}:6443|g" "$cfg"
      sed -i "s|server: http://.*:8080|server: https://${CONTROL_PLANE_IP}:6443|g" "$cfg"
    done

    echo "✅ Kubeconfig fixed: ${CONTROL_PLANE_IP}:6443"
    
    # Verify connection
    if kubectl get nodes &>/dev/null; then
      echo "✅ kubectl connection working"
    else
      echo "⚠️  kubectl connection failed - cluster may not be ready"
    fi
  fi
else
  echo "ℹ️  Kind cluster not found (will be created on first use)"
fi

echo "✅ Post-start configuration complete"
