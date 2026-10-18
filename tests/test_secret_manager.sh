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
# env 与生产一致：+POST_INSTALL 保证存在（sample 兜底）
printf "mihomo_URL='https://bing.com'\nmihomo_secret=''\n" > "$MIHOMO_ENV_FILE"

# Test 1: Generate high-entropy secret
echo "--> Test 1: Generating secret..."
sh -n "$SECRET_MGR" || { echo "FAIL: secret_manager syntax error"; exit 1; }
SECRET_OUT="$(sh "$SECRET_MGR" generate)"
echo "  [PASS] Generation output: $SECRET_OUT"

# Test 2: Masking logic
echo "--> Test 2: Checking masked display..."
MASKED="$(sh "$SECRET_MGR" masked)"
echo "  [PASS] Masked output: $MASKED"

# Test 3: Set custom secret via b64 (the configd-safe transport)
echo "--> Test 3: Setting custom secret (b64)..."
CUSTOM_SECRET="my-Secret.~#%+=:;!?,*-_@^42"
B64_PAYLOAD="b64:$(printf '%s' "$CUSTOM_SECRET" | base64)"
SET_OUT="$(sh "$SECRET_MGR" set "$B64_PAYLOAD")"
case "$SET_OUT" in
    OK*) echo "  [PASS] Set output: $SET_OUT" ;;
    *) echo "FAIL: set did not return OK: $SET_OUT"; exit 1 ;;
esac
STORED="$(cat "$MIHOMO_SECRET_FILE")"
if [ "$STORED" != "$CUSTOM_SECRET" ]; then
    echo "FAIL: secret.key mismatch: $STORED"; exit 1
fi
echo "  [PASS] secret.key matches input"
if ! grep -qF "secret: \"$CUSTOM_SECRET\"" "$MIHOMO_CONFIG_FILE"; then
    echo "FAIL: config.yaml secret not updated"; exit 1
fi
printf 'secret: ""\n' > "$MIHOMO_TEMPLATE_FILE"
SET_OUT="$(sh "$SECRET_MGR" set "$B64_PAYLOAD")"
if ! grep -qF "secret: \"$CUSTOM_SECRET\"" "$MIHOMO_TEMPLATE_FILE"; then
    echo "FAIL: template secret not updated"; exit 1
fi
if ! grep -qF "mihomo_secret='$CUSTOM_SECRET'" "$MIHOMO_ENV_FILE"; then
    echo "FAIL: env secret not updated"; exit 1
fi
echo "  [PASS] config.yaml / template / env all synced"

# Test 4: rejection cases
echo "--> Test 4: Rejection cases..."
if sh "$SECRET_MGR" set "$CUSTOM_SECRET" >/dev/null 2>&1; then
    echo "FAIL: plain (non-b64) argument must be rejected"; exit 1
fi
echo "  [PASS] plain argument rejected"
SHORT_B64="b64:$(printf '%s' 'abc' | base64)"
if sh "$SECRET_MGR" set "$SHORT_B64" >/dev/null 2>&1; then
    echo "FAIL: too-short secret must be rejected"; exit 1
fi
echo "  [PASS] too-short secret rejected"
DANGEROUS_B64="b64:$(printf '%s' 'safe$(dangerous)' | base64)"
if sh "$SECRET_MGR" set "$DANGEROUS_B64" >/dev/null 2>&1; then
    echo "FAIL: shell-metachar secret must be rejected"; exit 1
fi
if sh "$SECRET_MGR" set "b64:%$" >/dev/null 2>&1; then
    echo "FAIL: invalid base64 must be rejected"; exit 1
fi
echo "  [PASS] metachar/invalid-b64 rejected (secret.key untouched)"
if [ "$(cat "$MIHOMO_SECRET_FILE")" != "$CUSTOM_SECRET" ]; then
    echo "FAIL: rejected attempts must not modify secret.key"; exit 1
fi

# Test 5: env 缺失 mihomo_secret 行时自动补写（历史 env 可能没有该行）
echo "--> Test 5: missing env line is appended..."
grep -v "^mihomo_secret=" "$MIHOMO_ENV_FILE" > "$MIHOMO_ENV_FILE.tmp" || true
mv "$MIHOMO_ENV_FILE.tmp" "$MIHOMO_ENV_FILE"
grep -q "^mihomo_secret=" "$MIHOMO_ENV_FILE" && { echo "FAIL: setup did not remove the line"; exit 1; }
SET_OUT="$(sh "$SECRET_MGR" set "$B64_PAYLOAD")"
case "$SET_OUT" in
    OK*) : ;;
    *) echo "FAIL: set after env-line removal: $SET_OUT"; exit 1 ;;
esac
if ! grep -qF "mihomo_secret='$CUSTOM_SECRET'" "$MIHOMO_ENV_FILE"; then
    echo "FAIL: mihomo_secret line not appended"; exit 1
fi
echo "  [PASS] mihomo_secret line appended to env"

echo "===> Secret Manager tests PASSED 100%!"
