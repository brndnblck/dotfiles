#!/usr/bin/env bash

# Simple syntax validation script
set -e

echo "Validating shell script syntax..."

# Test main scripts
echo "Testing main scripts..."
bash -n script/bootstrap
bash -n script/test

# Test helper scripts
echo "Testing helper scripts..."
for helper in script/helpers/*; do
    if [ -f "$helper" ]; then
        echo "  Testing $helper"
        bash -n "$helper"
    fi
done

# Test template scripts
echo "Testing template scripts..."
find . -name "*.sh.tmpl" -print0 | while IFS= read -r -d '' template; do
    echo "  Testing $template"
    bash -n "$template"
done

echo "✓ All syntax validation passed!"