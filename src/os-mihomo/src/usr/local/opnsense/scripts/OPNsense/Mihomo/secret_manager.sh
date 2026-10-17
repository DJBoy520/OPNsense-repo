#!/bin/sh
set -eu

SECRET_FILE="${MIHOMO_SECRET_FILE:-/usr/local/etc/mihomo/secret.key}"
CONFIG_FILE="${MIHOMO_CONFIG_FILE:-/usr/local/etc/mihomo/config.yaml}"
TEMPLATE_FILE="${MIHOMO_TEMPLATE_FILE:-/usr/local/etc/mihomo/sub/template_config.yaml}"
ENV_FILE="${MIHOMO_ENV_FILE:-/usr/local/etc/mihomo/sub/env}"

generate_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32
    elif [ -r /dev/urandom ]; then
        head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
    elif command -v uuidgen >/dev/null 2>&1; then
        u1="$(uuidgen | tr -d '-')"
        u2="$(uuidgen | tr -d '-')"
        printf "%s%s" "$u1" "$u2"
    else
        echo "error: no secure CSPRNG available" >&2
        exit 1
    fi
}

cmd="${1:-get}"

case "$cmd" in
    generate|regen|rotate)
        NEW_SECRET="$(generate_secret)"
        mkdir -p "$(dirname "$SECRET_FILE")"
        touch "$SECRET_FILE"
        chmod 0600 "$SECRET_FILE"
        printf "%s" "$NEW_SECRET" > "$SECRET_FILE"

        # secret 经临时 sed 脚本传递，避免出现在进程参数（ps 可见）
        SED_SCRIPT="$(mktemp)"
        chmod 0600 "$SED_SCRIPT" 2>/dev/null || true
        for f in "$CONFIG_FILE" "$TEMPLATE_FILE"; do
            if [ -f "$f" ]; then
                chmod 0600 "$f" 2>/dev/null || true
                printf 's/^secret:.*/secret: "%s"/\n' "$NEW_SECRET" > "$SED_SCRIPT"
                sed -i '' -f "$SED_SCRIPT" "$f" 2>/dev/null || sed -i -f "$SED_SCRIPT" "$f" 2>/dev/null || true
            fi
        done

        if [ -f "$ENV_FILE" ]; then
            chmod 0600 "$ENV_FILE" 2>/dev/null || true
            printf 's/^mihomo_secret=.*/mihomo_secret="%s"/\n' "$NEW_SECRET" > "$SED_SCRIPT"
            sed -i '' -f "$SED_SCRIPT" "$ENV_FILE" 2>/dev/null || sed -i -f "$SED_SCRIPT" "$ENV_FILE" 2>/dev/null || true
        fi
        rm -f "$SED_SCRIPT"
        echo "OK: secret generated and secured"
        ;;
    get)
        if [ -s "$SECRET_FILE" ]; then
            cat "$SECRET_FILE"
        elif [ -f "$CONFIG_FILE" ]; then
            sed -n 's/^secret:[[:space:]]*["'\'']*\([^"'\'']*\)["'\'']*/\1/p' "$CONFIG_FILE"
        else
            echo ""
        fi
        ;;
    masked|sanitize)
        if [ -s "$SECRET_FILE" ]; then
            SECRET_VAL="$(cat "$SECRET_FILE")"
        elif [ -f "$CONFIG_FILE" ]; then
            SECRET_VAL="$(sed -n 's/^secret:[[:space:]]*["'\'']*\([^"'\'']*\)["'\'']*/\1/p' "$CONFIG_FILE")"
        else
            SECRET_VAL=""
        fi
        if [ -z "$SECRET_VAL" ]; then
            echo "NOT_CONFIGURED"
        else
            len="${#SECRET_VAL}"
            if [ "$len" -le 8 ]; then
                echo "********"
            else
                prefix="$(echo "$SECRET_VAL" | cut -c 1-4)"
                echo "${prefix}************************************"
            fi
        fi
        ;;
    *)
        echo "usage: $0 generate|get|masked" >&2
        exit 1
        ;;
esac
