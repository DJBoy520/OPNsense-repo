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

# 新密钥落盘 secret.key 并同步 config.yaml / 订阅模板 / sub/env 三处
# （订阅重合成与外部面板登录读的都是这三处，缺一处都会回退旧值）
apply_secret_files() {
    _new_secret="$1"

    mkdir -p "$(dirname "$SECRET_FILE")"
    touch "$SECRET_FILE"
    chmod 0600 "$SECRET_FILE"
    printf "%s" "$_new_secret" > "$SECRET_FILE"

    # secret 经临时 sed 脚本传递，避免出现在进程参数（ps 可见）
    SED_SCRIPT="$(mktemp)"
    chmod 0600 "$SED_SCRIPT" 2>/dev/null || true
    for f in "$CONFIG_FILE" "$TEMPLATE_FILE"; do
        [ -f "$f" ] || continue
        chmod 0600 "$f" 2>/dev/null || true
        printf 's/^secret:.*/secret: "%s"/\n' "$_new_secret" > "$SED_SCRIPT"
        sed -i '' -f "$SED_SCRIPT" "$f" 2>/dev/null || sed -i -f "$SED_SCRIPT" "$f" 2>/dev/null || true
        # 行缺失时补写（YAML 顶级键，列 0 追加合法）
        grep -q '^secret:' "$f" || printf 'secret: "%s"\n' "$_new_secret" >> "$f"
    done

    if [ -f "$ENV_FILE" ]; then
        chmod 0600 "$ENV_FILE" 2>/dev/null || true
        printf "s/^mihomo_secret=.*/mihomo_secret='%s'/\n" "$_new_secret" > "$SED_SCRIPT"
        sed -i '' -f "$SED_SCRIPT" "$ENV_FILE" 2>/dev/null || sed -i -f "$SED_SCRIPT" "$ENV_FILE" 2>/dev/null || true
        # 行缺失时补写（env 为 POSIX 单引号赋值格式，与 env.sample 一致）
        grep -q '^mihomo_secret=' "$ENV_FILE" || printf "mihomo_secret='%s'\n" "$_new_secret" >> "$ENV_FILE"
    fi
    rm -f "$SED_SCRIPT"
}

# configd 对 %s 参数做 shell 展开：set 子命令只接受 b64: 前缀（base64 字母表
# 无 shell 元字符），密钥本体永不出现在命令行。解码结果写到 stdout。
# CLI 侧 base64(1) 按 76 列折行，先剥离全部空白再解码。
decode_b64() {
    _clean="$(printf '%s' "$1" | tr -d ' \n\r\t')"
    _decoded="$(printf '%s' "$_clean" | base64 -d 2>/dev/null)" && { printf '%s' "$_decoded"; return 0; }
    _decoded="$(printf '%s' "$_clean" | openssl base64 -d -A 2>/dev/null)" && { printf '%s' "$_decoded"; return 0; }
    return 1
}

# 自定义密钥白名单：字母数字 + . _ ~ @ # % ^ + = : ; , ! ? * -
# 排除引号/反引号/$/&/\/|/空格/控制字符，保证 sed 替换、YAML 双引号、
# env 单引号三种落地语境均无需转义。
# 注意：不能写成 case 括号模式——dash 词法层会把 [..;..] 里的分号当分隔符
is_safe_custom_secret() {
    [ -n "$1" ] || return 1
    _residue="$(printf '%s' "$1" | tr -d 'A-Za-z0-9._~@#%^+=:;,!?*-')"
    [ -z "$_residue" ]
}

cmd="${1:-get}"

case "$cmd" in
    generate|regen|rotate)
        NEW_SECRET="$(generate_secret)"
        apply_secret_files "$NEW_SECRET"
        echo "OK: secret generated and secured"
        ;;
    set)
        RAW_ARG="${2:-}"
        if [ "${RAW_ARG#b64:}" = "$RAW_ARG" ] || [ -z "$RAW_ARG" ]; then
            echo "error: set requires a b64:-prefixed argument" >&2
            exit 1
        fi
        if ! NEW_SECRET="$(decode_b64 "${RAW_ARG#b64:}")" || [ -z "$NEW_SECRET" ]; then
            echo "error: secret base64 decode failed" >&2
            exit 1
        fi
        LEN="${#NEW_SECRET}"
        if [ "$LEN" -lt 4 ] || [ "$LEN" -gt 128 ]; then
            echo "error: secret length must be 4-128 characters" >&2
            exit 1
        fi
        if ! is_safe_custom_secret "$NEW_SECRET"; then
            echo "error: secret contains characters outside the allowed set" >&2
            exit 1
        fi
        apply_secret_files "$NEW_SECRET"
        echo "OK: secret updated and secured"
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
        echo "usage: $0 generate|set|get|masked" >&2
        exit 1
        ;;
esac
