#!/bin/sh
set -eu

CONFIG_DIR="/usr/local/etc/mihomo"
TARGET_CONFIG="$CONFIG_DIR/config.yaml"
BACKUP_CONFIG="$CONFIG_DIR/config.yaml.bak"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[ "$#" -ge 1 ] || die "usage: $0 <new_config_file_path> [reload|noreload]"

NEW_CONFIG="$1"
RELOAD_FLAG="${2:-reload}"

[ -f "$NEW_CONFIG" ] || die "new configuration file not found: $NEW_CONFIG"
[ -s "$NEW_CONFIG" ] || die "new configuration file is empty: $NEW_CONFIG"

mkdir -p "$CONFIG_DIR"

# 1. Create a secure temporary file with 0600 permissions
TMP_FILE="$(mktemp "$CONFIG_DIR/config.yaml.tmp.XXXXXX")"
chmod 0600 "$TMP_FILE"

cleanup() {
    if [ -f "$TMP_FILE" ]; then
        rm -f "$TMP_FILE"
    fi
}
trap cleanup EXIT INT TERM

# 2. Copy content into temporary file
cat "$NEW_CONFIG" > "$TMP_FILE"

# 3. Perform dry-run validation using official mihomo binary
echo "==> Step 1: Validating new configuration via mihomo -t"
if command -v mihomo >/dev/null 2>&1; then
    MIHOMO_BIN="mihomo"
elif [ -x "/usr/local/bin/mihomo" ]; then
    MIHOMO_BIN="/usr/local/bin/mihomo"
else
    MIHOMO_BIN=""
fi

if [ -n "$MIHOMO_BIN" ]; then
    if ! "$MIHOMO_BIN" -t -d "$CONFIG_DIR" -f "$TMP_FILE" >/dev/null 2>&1; then
        echo "==> Configuration syntax or rule error detected by mihomo -t" >&2
        die "Validation failed! The existing running configuration remains untouched."
    fi
    echo "==> Validation passed."
else
    echo "==> Warning: mihomo binary not found in PATH, skipping binary dry-run"
fi

# 4. Backup existing configuration if present
if [ -f "$TARGET_CONFIG" ]; then
    echo "==> Step 2: Backing up current configuration to $BACKUP_CONFIG"
    cp -f "$TARGET_CONFIG" "$BACKUP_CONFIG"
    chmod 0600 "$BACKUP_CONFIG" 2>/dev/null || true
fi

# 5. Atomic rename to production target
echo "==> Step 3: Performing atomic rename"
chmod 0600 "$TMP_FILE"
mv -f "$TMP_FILE" "$TARGET_CONFIG"
chmod 0600 "$TARGET_CONFIG"

echo "==> Configuration successfully updated to $TARGET_CONFIG (permissions: 0600)"

# 6. Trigger reload if requested
if [ "$RELOAD_FLAG" = "reload" ]; then
    echo "==> Step 4: Reloading Mihomo daemon"
    if [ -x "/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh" ]; then
        /usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh reload || true
    fi
fi

echo "OK: atomic configuration update completed"
