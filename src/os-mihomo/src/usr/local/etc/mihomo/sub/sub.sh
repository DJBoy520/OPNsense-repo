#!/bin/sh
# 订阅拉取与配置更新脚本

#################### 初始化 ####################
Server_Dir=$(cd "$(dirname "$0")" && pwd)
ENV_MIHOMO_URL="${mihomo_URL:-}"
ENV_MIHOMO_SECRET="${mihomo_secret:-}"
[ -f "$Server_Dir/env" ] && . "$Server_Dir/env"
[ -n "$ENV_MIHOMO_URL" ] && mihomo_URL="$ENV_MIHOMO_URL"
[ -n "$ENV_MIHOMO_SECRET" ] && mihomo_secret="$ENV_MIHOMO_SECRET"

Conf_Dir="${MIHOMO_CONF_DIR:-$(cd "$Server_Dir/.." && pwd)}"
Temp_Dir="${MIHOMO_TEMP_DIR:-$Server_Dir/temp}"
Clash_Dir="${MIHOMO_DIR:-/usr/local/etc/mihomo}"
ATOMIC_UPDATER="${MIHOMO_ATOMIC_UPDATER:-/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh}"
SECRET_MANAGER="${MIHOMO_SECRET_MANAGER:-/usr/local/opnsense/scripts/OPNsense/Mihomo/secret_manager.sh}"
LOCK_DIR="${MIHOMO_LOCK_DIR:-/var/run/mihomo-sub.lock}"
LOCK_HELD=0
TMP_RAW=""
TMP_PROXIES=""
TMP_NAMES=""
TMP_FINAL=""
mkdir -p "$Conf_Dir" "$Temp_Dir"

command -v jq >/dev/null 2>&1 || {
  echo "缺少 jq 命令，请先安装"
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  echo "缺少 curl 命令，请先安装。"
  exit 1
}
command -v openssl >/dev/null 2>&1 || {
  echo "缺少 openssl 命令，请先安装。"
  exit 1
}

cleanup_tmp_files() {
    [ -n "$TMP_RAW" ] && rm -f "$TMP_RAW"
    [ -n "$TMP_PROXIES" ] && rm -f "$TMP_PROXIES"
    [ -n "$TMP_NAMES" ] && rm -f "$TMP_NAMES"
    [ -n "$TMP_FINAL" ] && rm -f "$TMP_FINAL"
    rm -f "$Conf_Dir/config.clean.yaml" "$Conf_Dir/config.new.yaml"
    [ "$LOCK_HELD" = "1" ] && rm -f "$LOCK_DIR/pid" 2>/dev/null || true
    [ "$LOCK_HELD" = "1" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
}

trap cleanup_tmp_files EXIT INT TERM

if mkdir "$LOCK_DIR" 2>/dev/null; then
    LOCK_HELD=1
    printf '%s\n' "$$" > "$LOCK_DIR/pid" 2>/dev/null || true
else
    # 锁残留检查：持有者进程已死则清理陈旧锁并继续
    _lock_pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [ -n "$_lock_pid" ] && ! kill -0 "$_lock_pid" 2>/dev/null; then
        echo "警告：发现陈旧锁（持有者 PID $_lock_pid 已不存在），自动清理后继续。"
        rm -rf "$LOCK_DIR"
        if mkdir "$LOCK_DIR" 2>/dev/null; then
            LOCK_HELD=1
            printf '%s\n' "$$" > "$LOCK_DIR/pid" 2>/dev/null || true
        else
            echo "错误：陈旧锁清理失败，请手动 rm -rf $LOCK_DIR"
            exit 9
        fi
    else
        echo "错误：订阅任务已在运行，请勿重复执行。"
        [ -f "$LOCK_DIR/pid" ] && echo "当前锁持有进程 PID: $(cat "$LOCK_DIR/pid" 2>/dev/null)"
        exit 9
    fi
fi

# mihomo订阅地址校验（仅允许 https，杜绝明文传输订阅凭据）
[ -z "$mihomo_URL" ] && {
    echo "错误：未设置 mihomo_URL 环境变量"
    exit 1
}
URL_SCHEME_CHECK=$(printf "%s" "$mihomo_URL" | tr '[:upper:]' '[:lower:]')
case "$URL_SCHEME_CHECK" in
    https://*) ;;
    http://*)
        echo "错误：订阅地址禁止使用 http://（订阅凭据会明文传输），请使用 https://"
        exit 1
        ;;
    *)
        echo "错误：mihomo_URL 必须以 https:// 开头"
        exit 1
        ;;
esac

# 安全密钥
if [ -n "$mihomo_secret" ]; then
    Secret="$mihomo_secret"
elif [ -x "$SECRET_MANAGER" ]; then
    Secret="$("$SECRET_MANAGER" get 2>/dev/null || true)"
fi
[ -z "$Secret" ] && Secret=$(openssl rand -hex 32)

# URL 脱敏函数（隐藏 path、query 参数及 token，只保留 scheme://host）
mask_url() {
    raw_url="$1"
    scheme=$(printf "%s" "$raw_url" | sed -n 's/^\([a-zA-Z][a-zA-Z0-9+.-]*:\/\/\).*/\1/p')
    host=$(printf "%s" "$raw_url" | sed 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##' | cut -d'/' -f1 | cut -d'?' -f1)
    echo "${scheme}${host}/***"
}

#################### 预清理临时文件 ####################
find "$Temp_Dir" -type f -exec rm -f {} \; 2>/dev/null

TMP_RAW=$(mktemp "$Temp_Dir/clash_config.XXXXXX") || {
    echo "创建临时文件失败：TMP_RAW"
    exit 1
}
TMP_PROXIES=$(mktemp "$Temp_Dir/proxies.XXXXXX") || {
    echo "创建临时文件失败：TMP_PROXIES"
    exit 1
}
TMP_NAMES=$(mktemp "$Temp_Dir/names.XXXXXX") || {
    echo "创建临时文件失败：TMP_NAMES"
    exit 1
}
TMP_FINAL=$(mktemp "$Temp_Dir/config.XXXXXX") || {
    echo "创建临时文件失败：TMP_FINAL"
    exit 1
}

#################### 下载配置 ####################
# 如果配置了私有 CUSTOM_SUBCONVERTER 则使用自建 subconverter 进行转换，否则直接下载原生 Clash/Mihomo YAML 订阅
if [ -n "${CUSTOM_SUBCONVERTER:-}" ]; then
    ENCODED_URL=$(printf "%s" "$mihomo_URL" | jq -s -R -r @uri)
    API_URL="${CUSTOM_SUBCONVERTER}?target=clash&url=${ENCODED_URL}&udp=true&clash.dns=true&list=false"
    TARGET_URL="$API_URL"
    DISPLAY_URL="$(mask_url "$CUSTOM_SUBCONVERTER") [custom subconverter]"
else
    TARGET_URL="$mihomo_URL"
    DISPLAY_URL="$(mask_url "$mihomo_URL")"
fi

echo ""
echo "尝试不使用代理从：$DISPLAY_URL 下载配置..."
if curl -fSL -sS --retry 3 -m 120 --connect-timeout 15 -o "$TMP_RAW" "$TARGET_URL"; then
    echo "下载成功：$TMP_RAW"
else
    echo "下载失败，尝试通过 SOCKS5 代理 127.0.0.1:7891 下载配置..."
    if curl -fSL -sS --retry 2 -m 120 --connect-timeout 15 --socks5-hostname 127.0.0.1:7891 -o "$TMP_RAW" "$TARGET_URL"; then
        echo "下载成功：$TMP_RAW"
    else
        echo "下载失败：$DISPLAY_URL"
        echo "请检查网络连接或 mihomo 是否运行并监听 127.0.0.1:7891"
        exit 2
    fi
fi

if [ ! -s "$TMP_RAW" ]; then
    echo "下载结果为空，订阅内容无效。"
    exit 1
fi

RAW_SIZE=$(wc -c < "$TMP_RAW" | tr -d ' ')
echo "下载文件大小: ${RAW_SIZE} 字节"

if head -n 20 "$TMP_RAW" | grep -Eiq '^(<!doctype html|<html|<head|<body)'; then
    echo "检测到返回内容为 HTML 页面，订阅可能失效或被拦截。"
    exit 1
fi

if ! grep -Eq '^[[:space:]]*proxies[[:space:]]*:' "$TMP_RAW"; then
    echo "下载结果缺少 proxies: 节点，订阅内容可能无效。"
    exit 1
fi
echo ""

#################### 合成配置 ####################
TEMPLATE_FILE="$Server_Dir/template_config.yaml"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "缺少模板文件：$TEMPLATE_FILE"
    exit 1
fi
if ! grep -q '__MIHOMO_PROXIES__' "$TEMPLATE_FILE" || ! grep -q '__MIHOMO_NODE_NAMES__' "$TEMPLATE_FILE"; then
    echo "模板文件缺少订阅占位符：__MIHOMO_PROXIES__ 或 __MIHOMO_NODE_NAMES__"
    exit 1
fi

# 只提取 proxies 顶层段，避免订阅里的 proxy-groups/rules 覆盖模板策略。
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
' "$TMP_RAW" | sed 's/www\.speedtet\.net/www.speedtest.net/g' > "$TMP_PROXIES"

if [ ! -s "$TMP_PROXIES" ]; then
    echo "提取代理节点失败，proxies 段为空。"
    exit 1
fi

NODE_COUNT=$(awk '
  BEGIN { count = 0 }
  /^[[:space:]]*proxies[[:space:]]*:/ { in_proxies = 1; next }
  in_proxies && /^[^[:space:]]/ { in_proxies = 0 }
  in_proxies && /^[[:space:]]*-[[:space:]]/ { count++ }
  END { print count }
' "$TMP_PROXIES" | tr -d ' ')
echo "提取节点数量: ${NODE_COUNT}"
if [ "${NODE_COUNT:-0}" -le 0 ] 2>/dev/null; then
    echo "提取到的代理节点数量为 0，停止应用。"
    exit 1
fi

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
' "$TMP_PROXIES" > "$TMP_NAMES"

if [ ! -s "$TMP_NAMES" ]; then
    echo "提取代理节点名称失败。"
    exit 1
fi

# 合成配置
echo "合成配置..."
sleep 1
awk -v proxies_file="$TMP_PROXIES" -v names_file="$TMP_NAMES" '
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
  { print }
' "$TEMPLATE_FILE" > "$TMP_FINAL"

if [ ! -s "$TMP_FINAL" ]; then
    echo "合成后的配置文件为空。"
    exit 1
fi

FINAL_SIZE=$(wc -c < "$TMP_FINAL" | tr -d ' ')
echo "合成配置大小: ${FINAL_SIZE} 字节"

# 在临时文件上完成 secret 注入（绝不触碰生产 config.yaml；secret 经环境变量传递，避免出现在进程参数里）
awk '!/^[[:space:]]*secret[[:space:]]*:/ { print }' "$TMP_FINAL" > "${TMP_FINAL}.clean" && mv "${TMP_FINAL}.clean" "$TMP_FINAL"

if grep -q '^external-ui:' "$TMP_FINAL"; then
    MIHOMO_SUB_SECRET="$Secret" awk '
      /^external-ui:/ {
          print;
          print "secret: \"" ENVIRON["MIHOMO_SUB_SECRET"] "\"";
          next
      }
      { print }
    ' "$TMP_FINAL" > "${TMP_FINAL}.withsecret" && mv "${TMP_FINAL}.withsecret" "$TMP_FINAL"
else
    printf 'secret: "%s"\n' "$Secret" >> "$TMP_FINAL"
fi
chmod 600 "$TMP_FINAL" 2>/dev/null || true
echo "合成完成!"
echo ""

#################### 原子应用配置并重启 ####################
# 交由 atomic_config_updater：mihomo -t 校验通过才备份并原子替换 config.yaml，
# 校验失败时生产配置保持不变（坏订阅永远不会覆盖好配置）。
echo "应用配置..."
if [ -x "$ATOMIC_UPDATER" ]; then
    if ! "$ATOMIC_UPDATER" "$TMP_FINAL" reload; then
        echo "原子更新配置失败！生产配置保持不变。"
        exit 1
    fi
else
    echo "错误：未找到原子更新脚本 $ATOMIC_UPDATER"
    exit 1
fi
echo ""

#################### 输出仪表盘信息 ####################
sleep 1
# 优先获取防火墙的 LAN，其次 OPT1，最后回退到私网地址
LAN_IP=$(
  /usr/local/bin/php -r '
    require_once("/etc/inc/config.inc");
    require_once("/etc/inc/interfaces.inc");

    $candidates = array("lan", "opt1");

    foreach ($candidates as $name) {
        $if = get_real_interface($name);
        if (!empty($if)) {
            $ip = get_interface_ip($if);
            if (!empty($ip)) {
                echo $ip;
                exit;
            }
        }
    }
  ' 2>/dev/null
)

# 如果接口函数没有取到，再回退到本机私网地址
[ -n "$LAN_IP" ] || LAN_IP=$(
  ifconfig 2>/dev/null | awk '
    /^[[:alnum:]_.:-]+:/ {
      iface=$1
      sub(/:.*/, "", iface)
      skip=(iface ~ /^(lo|tun|pflog|pfsync|enc|gif|gre|stf|ovpn|wg)/)
      next
    }
    /inet / {
      ip=$2
      if (!skip &&
          ip != "127.0.0.1" &&
          ip !~ /^169\.254\./ &&
          ip ~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/) {
        print ip
        exit
      }
    }
  '
)

# 如果还是取不到，就给一个兜底提示
if [ -n "$LAN_IP" ]; then
  echo "面板访问（API 仅监听 127.0.0.1，需 SSH 隧道）:"
  echo "  ssh -L 9090:127.0.0.1:9090 root@${LAN_IP}  然后本机打开 http://127.0.0.1:9090/ui"
else
  echo "面板访问：未能自动获取 LAN/OPT1 地址，请手动 SSH 隧道 -L 9090:127.0.0.1:9090"
fi

if [ -x "$SECRET_MANAGER" ]; then
    MASKED_SECRET="$("$SECRET_MANAGER" masked 2>/dev/null || true)"
    if [ -n "$MASKED_SECRET" ]; then
        echo "仪表盘访问密钥: ${MASKED_SECRET}"
    else
        echo "仪表盘访问密钥: 已配置"
    fi
else
    echo "仪表盘访问密钥: 已配置"
fi
echo ""

#################### 清理临时文件 ####################
cleanup_tmp_files

