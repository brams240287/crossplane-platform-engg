#!/bin/bash
set -e

echo "🔐 Setting up Azure Credentials for Crossplane..."
echo ""

# Configuration
NAMESPACE="${NAMESPACE:-crossplane-system}"
SECRET_NAME="azure-secret"
ENV_FILE=".env"
JSON_FILE="azure-credentials.json"

# Function to prompt for input
prompt_input() {
    local var_name=$1
    local prompt_text=$2
    local is_secret=$3
    
    if [ -z "${!var_name}" ]; then
        if [ "$is_secret" = "true" ]; then
            read -sp "${prompt_text}: " value
            echo ""
        else
            read -p "${prompt_text}: " value
        fi
        eval "$var_name='$value'"
    fi
}

# Check if .env already exists
if [ -f "$ENV_FILE" ]; then
    echo "📋 Found existing .env file"
    read -p "Do you want to use it? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "✅ Loading credentials from .env"
        source "$ENV_FILE"
    else
        rm "$ENV_FILE"
        echo "🗑️  Removed old .env file"
    fi
fi

# Prompt for credentials if not set
echo "📝 Please provide Azure credentials:"
echo ""

prompt_input AZURE_SUBSCRIPTION_ID "Azure Subscription ID" false
prompt_input AZURE_TENANT_ID "Azure Tenant ID" false
prompt_input AZURE_CLIENT_ID "Azure Client ID (App/Service Principal)" false
prompt_input AZURE_CLIENT_SECRET "Azure Client Secret" true

echo ""
echo "💾 Saving credentials to .env file..."

# Create .env file
cat > "$ENV_FILE" <<EOF
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
EOF

echo "✅ Created .env file"

# Generate JSON credentials file
echo "📄 Generating azure-credentials.json..."
cat > "$JSON_FILE" <<EOF
{
  "clientId": "${AZURE_CLIENT_ID}",
  "clientSecret": "${AZURE_CLIENT_SECRET}",
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "tenantId": "${AZURE_TENANT_ID}"
}
EOF

# Check if secret already exists
if kubectl get secret "$SECRET_NAME" -n "$NAMESPACE" &> /dev/null; then
    echo "⚠️  Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'"
    read -p "Do you want to replace it? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete secret "$SECRET_NAME" -n "$NAMESPACE"
        echo "🗑️  Deleted existing secret"
    else
        echo "✅ Keeping existing secret"
        rm "$JSON_FILE"
        exit 0
    fi
fi

# Create Kubernetes secret
echo "🔑 Creating Kubernetes secret..."
kubectl create secret generic "$SECRET_NAME" \
  --from-file=creds=./"$JSON_FILE" \
  --namespace "$NAMESPACE"

echo "✅ Secret created successfully"

# Verify secret
echo ""
echo "🔍 Verifying secret..."
kubectl get secret "$SECRET_NAME" -n "$NAMESPACE"

# Clean up JSON file (keep .env)
echo ""
echo "🧹 Cleaning up..."
rm "$JSON_FILE"
echo "✅ Removed azure-credentials.json (kept .env file)"

echo ""
echo "🎉 Azure credentials setup complete!"
echo ""
echo "📋 Summary:"
echo "  • .env file: $ENV_FILE (preserved for future use)"
echo "  • Kubernetes secret: $SECRET_NAME in namespace $NAMESPACE"
echo "  • Subscription: $AZURE_SUBSCRIPTION_ID"
echo ""
echo "⚠️  Keep your .env file secure and never commit it to git!"
