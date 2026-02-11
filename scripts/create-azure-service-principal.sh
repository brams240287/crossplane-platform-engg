#!/bin/bash
set -e

echo "🔐 Creating Azure Service Principal for Crossplane..."
echo ""

# Prompt for subscription ID
read -p "Enter your Azure Subscription ID: " SUBSCRIPTION_ID

# Set the subscription
echo "📋 Setting active subscription..."
az account set --subscription "$SUBSCRIPTION_ID"

# Get subscription and tenant details
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "✅ Using subscription: $SUBSCRIPTION_NAME"
echo "   Subscription ID: $SUBSCRIPTION_ID"
echo "   Tenant ID: $TENANT_ID"
echo ""

# Prompt for service principal name
SP_NAME="crossplane-sp-$(date +%s)"
read -p "Enter Service Principal name (default: $SP_NAME): " input
SP_NAME="${input:-$SP_NAME}"

# Create service principal
echo ""
echo "🔨 Creating service principal: $SP_NAME..."
echo "   This may take a few seconds..."
echo ""

SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Contributor \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --output json)

# Extract credentials
CLIENT_ID=$(echo "$SP_OUTPUT" | grep -o '"appId": "[^"]*' | cut -d'"' -f4)
CLIENT_SECRET=$(echo "$SP_OUTPUT" | grep -o '"password": "[^"]*' | cut -d'"' -f4)

echo "✅ Service Principal created successfully!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CREDENTIALS (save these securely!):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_CLIENT_SECRET=$CLIENT_SECRET"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Ask if user wants to save to .env
read -p "Do you want to save these to .env file? (Y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    cat > .env <<EOF
AZURE_CLIENT_ID=${CLIENT_ID}
AZURE_CLIENT_SECRET=${CLIENT_SECRET}
AZURE_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
AZURE_TENANT_ID=${TENANT_ID}
EOF
    echo "✅ Saved to .env file"
    echo ""
    
    # Ask if user wants to continue with Kubernetes secret creation
    read -p "Do you want to create Kubernetes secret now? (Y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        bash "$(dirname "$0")/setup-azure-credentials.sh"
    else
        echo "💡 Run './scripts/setup-azure-credentials.sh' when ready to create the secret"
    fi
else
    echo "💡 Make sure to save these credentials securely!"
    echo "💡 Run './scripts/setup-azure-credentials.sh' when ready to create the secret"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "⚠️  Important Notes:"
echo "  • Keep these credentials secure and never commit them to git"
echo "  • The service principal has Contributor role on your subscription"
echo "  • You can manage this SP in Azure Portal under 'App Registrations'"
