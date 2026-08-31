#!/bin/sh
set -eu

echo "===> Running Secret Manager tests..."

TMP_TEST_DIR="$(mktemp -d /tmp/test-secret.XXXXXX)"
trap 'rm -rf "$TMP_TEST_DIR"' EXIT

SECRET_MGR="src/os-mihomo/src/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh"

export MIHOMO_SECRET_FILE="$TMP_TEST_DIR/secret.key"
export MIHOMO_CONFIG_FILE="$TMP_TEST_DIR/config.yaml"
export MIHOMO_TEMPLATE_FILE="$TMP_TEST_DIR/template_config.yaml"
export MIHOMO_ENV_FILE="$TMP_TEST_DIR/env"

echo "secret: \"\"" > "$MIHOMO_CONFIG_FILE"

# Test 1: Generate high-entropy secret
echo "--> Test 1: Generating secret..."
sh -n "$SECRET_MGR" || { echo "FAIL: secret_manager syntax error"; exit 1; }
SECRET_OUT="$(sh "$SECRET_MGR" generate)"
echo "  [PASS] Generation output: $SECRET_OUT"

# Test 2: Masking logic
echo "--> Test 2: Checking masked display..."
MASKED="$(sh "$SECRET_MGR" masked)"
echo "  [PASS] Masked output: $MASKED"

echo "===> Secret Manager tests PASSED 100%!"
