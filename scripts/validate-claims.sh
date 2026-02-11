#!/bin/bash
set -e

echo "🔍 Validating Crossplane Claims..."

CLAIMS_DIR="claims"
ERRORS=0

# Function to validate naming convention
validate_naming() {
    local file=$1
    local rg_name=$(yq eval '.spec.parameters.resourceGroupName // ""' "$file")
    
    if [[ -n "$rg_name" ]]; then
        if [[ ! "$rg_name" =~ ^rg-[a-z0-9-]{3,24}$ ]]; then
            echo "❌ $file: Invalid resource group name '$rg_name'"
            echo "   Must match pattern: rg-{env}-{purpose}-{region}"
            ((ERRORS++))
        else
            echo "✅ $file: Valid naming"
        fi
    fi
}

# Function to validate CIDR ranges
validate_cidr() {
    local file=$1
    local cidr=$(yq eval '.spec.parameters.addressSpace // ""' "$file")
    
    if [[ -n "$cidr" ]]; then
        # Check if it's a valid CIDR
        if [[ ! "$cidr" =~ ^10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
            echo "❌ $file: Invalid CIDR '$cidr'"
            ((ERRORS++))
        fi
    fi
}

# Validate all claim files
find "$CLAIMS_DIR" -name "*.yaml" -o -name "*.yml" | while read -r file; do
    echo ""
    echo "📄 Validating: $file"
    
    # Check if file is valid YAML
    if ! yq eval '.' "$file" > /dev/null 2>&1; then
        echo "❌ $file: Invalid YAML syntax"
        ((ERRORS++))
        continue
    fi
    
    # Validate against Kubernetes schema
    if ! kubectl apply --dry-run=client -f "$file" > /dev/null 2>&1; then
        echo "❌ $file: Kubernetes validation failed"
        ((ERRORS++))
        continue
    fi
    
    validate_naming "$file"
    validate_cidr "$file"
done

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All validations passed!"
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    exit 1
fi
