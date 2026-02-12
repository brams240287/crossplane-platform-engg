#!/bin/bash
set -e

# Enable ** globbing and make unmatched globs expand to empty.
shopt -s globstar nullglob

echo "🔍 Validating Crossplane Compositions..."

cluster_reachable() {
    # In CI, kubectl may have no kubeconfig and will default to localhost:8080.
    # We only run kubectl-based validation when an API server is reachable.
    kubectl version --request-timeout='2s' >/dev/null 2>&1
}

KUBE_VALIDATION=${KUBE_VALIDATION:-auto}
if [ "$KUBE_VALIDATION" = "auto" ]; then
    if cluster_reachable; then
        KUBE_VALIDATION=enabled
    else
        KUBE_VALIDATION=disabled
    fi
fi

if [ "$KUBE_VALIDATION" = "disabled" ]; then
    echo "ℹ️  Skipping kubectl schema/API validation (no reachable Kubernetes API server)."
    echo "    Tip: run with KUBE_VALIDATION=enabled when you have cluster access."
fi

ERRORS=0

# Validate XRDs
echo ""
echo "📋 Validating XRDs..."
for xrd in manifests/compositions/**/xrd-*.yaml; do
    if [ -f "$xrd" ]; then
        echo "  Checking: $xrd"
        if [ "$KUBE_VALIDATION" = "enabled" ]; then
            if kubectl apply --dry-run=client -f "$xrd" > /dev/null 2>&1; then
                echo "    ✅ Valid"
            else
                echo "    ❌ Invalid"
                kubectl apply --dry-run=client -f "$xrd" || true
                ((ERRORS++))
            fi
        else
            echo "    ⏭️  Skipped (kubectl validation disabled)"
        fi
    fi
done

# Validate Compositions
echo ""
echo "🔧 Validating Compositions..."
for comp in manifests/compositions/**/composition-*.yaml; do
    if [ -f "$comp" ]; then
        echo "  Checking: $comp"
        if [ "$KUBE_VALIDATION" = "enabled" ]; then
            if kubectl apply --dry-run=client -f "$comp" > /dev/null 2>&1; then
                echo "    ✅ Valid"
            else
                echo "    ❌ Invalid"
                kubectl apply --dry-run=client -f "$comp" || true
                ((ERRORS++))
            fi
        else
            echo "    ⏭️  Skipped (kubectl validation disabled)"
        fi
    fi
done

# Validate YAML syntax
echo ""
echo "📝 Validating YAML syntax..."
if command -v yamllint &> /dev/null; then
    # Keep local validation aligned with CI (see .github/workflows/platform-deploy.yml).
    # By default, lint issues are reported but do not fail the script.
    # Set STRICT_LINT=1 to make yamllint failures fail validation.
    STRICT_LINT=${STRICT_LINT:-0}
    YAMLLINT_CONFIG='{extends: default, rules: {line-length: {max: 120}, document-start: disable}}'

    if ! yamllint -d "$YAMLLINT_CONFIG" manifests/; then
        if [ "$STRICT_LINT" = "1" ]; then
            ((ERRORS++))
        else
            echo "  ⚠️  yamllint reported issues (non-fatal). Set STRICT_LINT=1 to fail on lint."
        fi
    fi
else
    echo "  ⚠️  yamllint not installed, skipping"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "✅ All validations passed!"
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    exit 1
fi
