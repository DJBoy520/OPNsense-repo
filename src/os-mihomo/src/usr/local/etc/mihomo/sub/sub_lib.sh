#!/bin/sh
# Mihomo 订阅合成函数库
# 提供加锁、解脱、URL 脱敏、节点提取、配置合成、缓存持久化与状态记录等共享能力。
# 本文件仅供 source 引入，source 时零副作用。

MIHOMO_LOCK_DIR="${MIHOMO_LOCK_DIR:-/var/run/mihomo-sub.lock}"
MIHOMO_TEMPLATE_FILE="${MIHOMO_TEMPLATE_FILE:-/usr/local/etc/mihomo/sub/template_config.yaml}"
MIHOMO_RULES_FILE="${MIHOMO_RULES_FILE:-/usr/local/etc/mihomo/custom-rules.txt}"
MIHOMO_PANEL_STATE_FILE="${MIHOMO_PANEL_STATE_FILE:-/var/db/os-mihomo/panel-state.env}"
MIHOMO_STATUS_FILE="${MIHOMO_STATUS_FILE:-/var/db/os-mihomo/last-sub-update.json}"
MIHOMO_CACHE_FILE="${MIHOMO_CACHE_FILE:-/var/db/os-mihomo/subscription-cache.yaml}"
MIHOMO_SECRET_MANAGER="${MIHOMO_SECRET_MANAGER:-/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh}"
MIHOMO_ATOMIC_UPDATER="${MIHOMO_ATOMIC_UPDATER:-/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh}"
MIHOMO_BIN="${MIHOMO_BIN:-/usr/local/bin/mihomo}"
MIHOMO_CONF_DIR="${MIHOMO_CONF_DIR:-/usr/local/etc/mihomo}"
LOCK_HELD="${LOCK_HELD:-0}"

# 订阅操作加锁（含陈旧锁自动清理机制）
mihomo_lib_lock_acquire() {
    if mkdir "$MIHOMO_LOCK_DIR" 2>/dev/null; then
        LOCK_HELD=1
        printf '%s\n' "$$" > "$MIHOMO_LOCK_DIR/pid" 2>/dev/null || true
        return 0
    fi
    _lock_pid="$(cat "$MIHOMO_LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$_lock_pid" ] && ! kill -0 "$_lock_pid" 2>/dev/null; then
        echo "警告：发现陈旧锁（持有者 PID $_lock_pid 已不存在），自动清理后重试。" >&2
        rm -rf "$MIHOMO_LOCK_DIR"
        if mkdir "$MIHOMO_LOCK_DIR" 2>/dev/null; then
            LOCK_HELD=1
            printf '%s\n' "$$" > "$MIHOMO_LOCK_DIR/pid" 2>/dev/null || true
            return 0
        fi
    fi
    return 1
}

# 释放锁
mihomo_lib_lock_release() {
    if [ "${LOCK_HELD:-0}" = "1" ]; then
        rm -f "$MIHOMO_LOCK_DIR/pid" 2>/dev/null || true
        rmdir "$MIHOMO_LOCK_DIR" 2>/dev/null || true
        LOCK_HELD=0
    fi
}

# URL 脱敏：保留 scheme://host，path/query 脱敏为 ***
mihomo_lib_mask_url() {
    _raw_url="${1:-}"
    _scheme="$(printf "%s" "$_raw_url" | sed -n 's/^\([a-zA-Z][a-zA-Z0-9+.-]*:\/\/\).*/\1/p')"
    _host="$(printf "%s" "$_raw_url" | sed 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##' | cut -d'/' -f1 | cut -d'?' -f1)"
    printf '%s%s/***\n' "$_scheme" "$_host"
}

# 提取 proxies 顶层段（含 www.speedtet.net 修正）
mihomo_lib_extract_proxies() {
    _raw_yaml="${1:-}"
    _out_file="${2:-}"
    [ -f "$_raw_yaml" ] || return 1
    [ -n "$_out_file" ] || return 1
    awk '
      /^[[:space:]]*proxies[[:space:]]*:/ {
          in_proxies = 1
          print
          next
      }
      in_proxies && /^[^[:space:]][^:]*[[:space:]]*:/ {
          exit
      }
      in_proxies {
          print
      }
    ' "$_raw_yaml" | sed 's/www\.speedtet\.net/www.speedtest.net/g' > "$_out_file"
}

# 提取节点名称列表（去重、去引号、转义并格式化为 YAML 项）
mihomo_lib_extract_names() {
    _names_proxies_file="${1:-}"
    _names_out_file="${2:-}"
    [ -f "$_names_proxies_file" ] || return 1
    [ -n "$_names_out_file" ] || return 1
    awk '
      function trim(s) {
          sub(/^[[:space:]]+/, "", s)
          sub(/[[:space:]]+$/, "", s)
          return s
      }
      function unquote(s) {
          s = trim(s)
          if ((substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") ||
              (substr(s, 1, 1) == "\047" && substr(s, length(s), 1) == "\047")) {
              s = substr(s, 2, length(s) - 2)
          }
          return s
      }
      function emit(s) {
          s = unquote(s)
          if (s != "" && !seen[s]++) {
              gsub(/\\/, "\\\\", s)
              gsub(/"/, "\\\"", s)
              print "      - \"" s "\""
          }
      }
      /^[[:space:]]*-[[:space:]]*\{/ {
          line = $0
          sub(/^[[:space:]]*-[[:space:]]*\{[[:space:]]*name:[[:space:]]*/, "", line)
          sub(/[[:space:]]*,[[:space:]]*server:.*/, "", line)
          emit(line)
          next
      }
      /^[[:space:]]*-[[:space:]]*name[[:space:]]*:/ {
          line = $0
          sub(/^[[:space:]]*-[[:space:]]*name[[:space:]]*:[[:space:]]*/, "", line)
          emit(line)
          next
      }
      /^[[:space:]]*name[[:space:]]*:/ {
          line = $0
          sub(/^[[:space:]]*name[[:space:]]*:[[:space:]]*/, "", line)
          emit(line)
          next
      }
    ' "$_names_proxies_file" > "$_names_out_file"
}

# 统计 proxies 中的节点数量
mihomo_lib_count_nodes() {
    _proxies_file="${1:-}"
    if [ ! -f "$_proxies_file" ]; then
        echo "0"
        return 0
    fi
    awk '
      BEGIN { count = 0 }
      /^[[:space:]]*proxies[[:space:]]*:/ { in_proxies = 1; next }
      in_proxies && /^[^[:space:]]/ { in_proxies = 0 }
      in_proxies && /^[[:space:]]*-[[:space:]]/ { count++ }
      END { print count }
    ' "$_proxies_file" | tr -d ' '
}

# 配置合成函数：
# 1. 占位符替换（proxies, names, custom_rules）
# 2. LAN 暴露处理（allow-lan, bind-address, authentication, lan-allowed-ips）
# 3. secret 注入
# 4. 权限设置 0600
mihomo_lib_compose() {
    _proxies_file="${1:-}"
    _out_file="${2:-}"

    [ -f "$_proxies_file" ] || {
        echo "错误：代理文件不存在：$_proxies_file" >&2
        return 1
    }
    [ -n "$_out_file" ] || {
        echo "错误：未指定输出文件路径" >&2
        return 1
    }

    # a) 检查模板及必要占位符
    if [ ! -f "$MIHOMO_TEMPLATE_FILE" ]; then
        echo "错误：缺少模板文件：$MIHOMO_TEMPLATE_FILE" >&2
        return 1
    fi
    if ! grep -q '__MIHOMO_PROXIES__' "$MIHOMO_TEMPLATE_FILE" || \
       ! grep -q '__MIHOMO_NODE_NAMES__' "$MIHOMO_TEMPLATE_FILE" || \
       ! grep -q '__MIHOMO_CUSTOM_RULES__' "$MIHOMO_TEMPLATE_FILE"; then
        echo "错误：模板文件缺少占位符：__MIHOMO_PROXIES__、__MIHOMO_NODE_NAMES__ 或 __MIHOMO_CUSTOM_RULES__" >&2
        return 1
    fi

    # b) 提取节点名称并进行占位符替换
    _compose_tmp_dir="$(dirname "$_out_file")"
    mkdir -p "$_compose_tmp_dir" 2>/dev/null || true

    _tmp_names="$(mktemp "$_compose_tmp_dir/names.XXXXXX" 2>/dev/null || mktemp /tmp/names.XXXXXX)"
    if ! mihomo_lib_extract_names "$_proxies_file" "$_tmp_names"; then
        rm -f "$_tmp_names"
        echo "错误：提取节点名称失败" >&2
        return 1
    fi

    _rules_src="/dev/null"
    if [ -n "$MIHOMO_RULES_FILE" ] && [ -f "$MIHOMO_RULES_FILE" ]; then
        _rules_src="$MIHOMO_RULES_FILE"
    fi

    _tmp_step1="$(mktemp "$_compose_tmp_dir/comp1.XXXXXX" 2>/dev/null || mktemp /tmp/comp1.XXXXXX)"

    awk -v proxies_file="$_proxies_file" -v names_file="$_tmp_names" -v rules_file="$_rules_src" '
      /^[[:space:]]*#[[:space:]]*__MIHOMO_PROXIES__[[:space:]]*$/ {
          while ((getline line < proxies_file) > 0) print line
          close(proxies_file)
          next
      }
      /^[[:space:]]*#[[:space:]]*__MIHOMO_NODE_NAMES__[[:space:]]*$/ {
          while ((getline line < names_file) > 0) print line
          close(names_file)
          next
      }
      /^[[:space:]]*#[[:space:]]*__MIHOMO_CUSTOM_RULES__[[:space:]]*$/ {
          while ((getline line < rules_file) > 0) {
              # 空行跳过；注释行原样缩进保留；规则行补 YAML 列表前缀（校验器存的是裸规则）
              if (line ~ /^[[:space:]]*$/) continue
              if (line ~ /^[[:space:]]*#/) { print "  " line } else { print "  - " line }
          }
          close(rules_file)
          next
      }
      { print }
    ' "$MIHOMO_TEMPLATE_FILE" > "$_tmp_step1"

    rm -f "$_tmp_names"

    if [ ! -s "$_tmp_step1" ]; then
        rm -f "$_tmp_step1"
        echo "错误：基础配置合成结果为空" >&2
        return 1
    fi

    # 解析 Secret
    _secret=""
    if [ -n "${mihomo_secret:-}" ]; then
        _secret="$mihomo_secret"
    elif [ -x "$MIHOMO_SECRET_MANAGER" ]; then
        _secret="$("$MIHOMO_SECRET_MANAGER" get 2>/dev/null || true)"
    fi
    if [ -z "$_secret" ]; then
        if command -v openssl >/dev/null 2>&1; then
            _secret="$(openssl rand -hex 32)"
        elif [ -r /dev/urandom ]; then
            _secret="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        else
            echo "错误：缺少安全随机数生成器" >&2
            rm -f "$_tmp_step1"
            return 1
        fi
    fi

    # c) LAN 暴露处理
    _lan_expose=0
    _lan_user="mihomo"
    if [ -f "$MIHOMO_PANEL_STATE_FILE" ]; then
        MIHOMO_LAN_EXPOSE=0
        MIHOMO_LAN_USER="mihomo"
        . "$MIHOMO_PANEL_STATE_FILE" 2>/dev/null || true
        _lan_expose="${MIHOMO_LAN_EXPOSE:-0}"
        _lan_user="${MIHOMO_LAN_USER:-mihomo}"
    fi

    _tmp_step2="$(mktemp "$_compose_tmp_dir/comp2.XXXXXX" 2>/dev/null || mktemp /tmp/comp2.XXXXXX)"

    if [ "$_lan_expose" = "1" ]; then
        _lan_net=""
        _php_bin="${PHP_BIN:-/usr/local/bin/php}"
        _render_script="${MIHOMO_TRANSPORT_RENDER:-/usr/local/opnsense/scripts/OPNsense/Mihomo/transport_render.php}"
        if [ -x "$_php_bin" ] && [ -f "$_render_script" ]; then
            _lan_net="$("$_php_bin" "$_render_script" lan-net 2>/dev/null || true)"
        fi
        if [ -z "$_lan_net" ]; then
            echo "# 提示：未获取到 LAN 网段（php 不存在或执行失败），lan-allowed-ips 保持原样"
        fi

        export MIHOMO_LAN_USER_VAL="$_lan_user"
        export MIHOMO_LAN_SECRET_VAL="$_secret"
        export MIHOMO_LAN_NET_VAL="$_lan_net"

        awk '
          BEGIN {
              lan_user = ENVIRON["MIHOMO_LAN_USER_VAL"]
              lan_secret = ENVIRON["MIHOMO_LAN_SECRET_VAL"]
              lan_net = ENVIRON["MIHOMO_LAN_NET_VAL"]
              in_lan_ips = 0
          }
          /^[[:space:]]*allow-lan:[[:space:]]*false/ {
              sub(/allow-lan:[[:space:]]*false/, "allow-lan: true")
              print
              next
          }
          /^[[:space:]]*bind-address:[[:space:]]*127\.0\.0\.1/ {
              # \047 是 POSIX awk 的单引号八进制转义（BSD awk 不支持 \x 转义）
              sub(/bind-address:[[:space:]]*127\.0\.0\.1/, "bind-address: \047*\047")
              print
              print "authentication:"
              print "  - \"" lan_user ":" lan_secret "\""
              next
          }
          /^[[:space:]]*lan-allowed-ips:[[:space:]]*/ {
              print
              in_lan_ips = 1
              if (lan_net != "") {
                  print "  - " lan_net
              }
              next
          }
          in_lan_ips && /^[[:space:]]*-[[:space:]]*(0\.0\.0\.0\/0|::\/0)[[:space:]]*$/ {
              if (lan_net != "") {
                  next
              }
          }
          in_lan_ips && /^[^[:space:]]/ {
              in_lan_ips = 0
          }
          { print }
        ' "$_tmp_step1" > "$_tmp_step2"
        rm -f "$_tmp_step1"
    else
        mv "$_tmp_step1" "$_tmp_step2"
    fi

    # d) secret 注入
    _tmp_step3="$(mktemp "$_compose_tmp_dir/comp3.XXXXXX" 2>/dev/null || mktemp /tmp/comp3.XXXXXX)"
    awk '!/^[[:space:]]*secret[[:space:]]*:/ { print }' "$_tmp_step2" > "$_tmp_step3"
    rm -f "$_tmp_step2"

    _tmp_step4="$(mktemp "$_compose_tmp_dir/comp4.XXXXXX" 2>/dev/null || mktemp /tmp/comp4.XXXXXX)"
    if grep -q '^external-ui:' "$_tmp_step3"; then
        MIHOMO_SUB_SECRET="$_secret" awk '
          /^external-ui:/ {
              print
              print "secret: \"" ENVIRON["MIHOMO_SUB_SECRET"] "\""
              next
          }
          { print }
        ' "$_tmp_step3" > "$_tmp_step4"
    else
        cat "$_tmp_step3" > "$_tmp_step4"
        printf 'secret: "%s"\n' "$_secret" >> "$_tmp_step4"
    fi
    rm -f "$_tmp_step3"

    # e) 输出文件权限为 0600
    chmod 0600 "$_tmp_step4" 2>/dev/null || true
    mv -f "$_tmp_step4" "$_out_file"
    chmod 0600 "$_out_file" 2>/dev/null || true
    return 0
}

# 缓存 proxies 文件并返回 sha256
mihomo_lib_cache_store() {
    _proxies_file="${1:-}"
    [ -f "$_proxies_file" ] || return 1
    _cache_dir="$(dirname "$MIHOMO_CACHE_FILE")"
    mkdir -p "$_cache_dir" 2>/dev/null || true
    _tmp_cache="$(mktemp "$_cache_dir/cache.XXXXXX" 2>/dev/null || mktemp /tmp/cache.XXXXXX)" || return 1
    chmod 0600 "$_tmp_cache" 2>/dev/null || true
    cat "$_proxies_file" > "$_tmp_cache"
    chmod 0600 "$_tmp_cache" 2>/dev/null || true
    mv -f "$_tmp_cache" "$MIHOMO_CACHE_FILE"
    chmod 0600 "$MIHOMO_CACHE_FILE" 2>/dev/null || true

    _hash=""
    if command -v sha256sum >/dev/null 2>&1; then
        _hash="$(sha256sum "$MIHOMO_CACHE_FILE" | awk '{print $1}')"
    elif command -v sha256 >/dev/null 2>&1; then
        _hash="$(sha256 -q "$MIHOMO_CACHE_FILE" 2>/dev/null || sha256 "$MIHOMO_CACHE_FILE" | awk '{print $NF}')"
    elif command -v shasum >/dev/null 2>&1; then
        _hash="$(shasum -a 256 "$MIHOMO_CACHE_FILE" | awk '{print $1}')"
    fi
    printf '%s\n' "$_hash"
}

# 状态写入：单行 JSON 写 MIHOMO_STATUS_FILE
mihomo_lib_status_write() {
    _res="${1:-failed}"
    _nodes="${2:-0}"
    _hash="${3:-}"
    _msg="${4:-}"

    case "$_nodes" in
        ''|*[!0-9]*) _nodes=0 ;;
    esac

    _clean_res="$(printf '%s' "$_res" | tr -d '\r\n' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    _clean_hash="$(printf '%s' "$_hash" | tr -d '\r\n' | sed 's/\\/\\\\/g; s/"/\\"/g')"
    _clean_msg="$(printf '%s' "$_msg" | tr -d '\r\n' | sed 's/\\/\\\\/g; s/"/\\"/g')"

    _status_dir="$(dirname "$MIHOMO_STATUS_FILE")"
    mkdir -p "$_status_dir" 2>/dev/null || true
    _tmp_status="$(mktemp "$_status_dir/status.XXXXXX" 2>/dev/null || mktemp /tmp/status.XXXXXX)" || return 1
    _now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    printf '{"time":"%s","result":"%s","nodes":%d,"cache_sha256":"%s","message":"%s"}\n' \
        "$_now" "$_clean_res" "$_nodes" "$_clean_hash" "$_clean_msg" > "$_tmp_status"
    chmod 0644 "$_tmp_status" 2>/dev/null || true
    mv -f "$_tmp_status" "$MIHOMO_STATUS_FILE"
}
