#!/bin/sh
set -eu

# Mihomo fail-open watchdog (socks-core mode)
# 探测对象：进程 / API(9090) / DNS(1053) / 传输层(tun 模式查 tun_mihomo，socks 模式查 7891 监听)
# 本模式不改 Unbound、不动主规则集；transport=transparent 时 fail-open 仅清空
# mihomo-transport anchor 恢复直连（route-to 不再指向已停的 socks 端口），
# DNS 由 AdGuardHome 的 fallback 上游自然回退，直连流量不受影响。

STATE_RUN_FILE="/var/run/mihomo_state.json"
STATE_DB_FILE="/var/db/os-mihomo/state.json"
PID_FILE="/var/run/mihomo.pid"
LOG_FILE="/var/log/mihomo_watchdog.log"
CONFIG_FILE="/usr/local/etc/mihomo/config.yaml"
SERVICE_MGR="/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh"
TRANSPORT_MGR="/usr/local/opnsense/scripts/OPNsense/Mihomo/transport_manager.sh"
TRANSPORT_MODE_FILE="/var/db/os-mihomo/transport-mode"
BIN="/usr/local/bin/mihomo"
CONF_DIR="/usr/local/etc/mihomo"
TUN_DEV="tun_mihomo"

log() {
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [WATCHDOG] %s\n" "$ts" "$*" | tee -a "$LOG_FILE" 2>/dev/null || true
}

tun_enabled() {
    [ -f "$CONFIG_FILE" ] || return 1
    awk '
        /^tun:[[:space:]]*$/ { in_tun=1; next }
        in_tun && /^[^[:space:]]/ { in_tun=0 }
        in_tun && /^[[:space:]]*enable:[[:space:]]*true/ { found=1; exit }
        END { exit !found }
    ' "$CONFIG_FILE" 2>/dev/null
}

get_current_state() {
    if [ -f "$STATE_RUN_FILE" ]; then
        sed -n 's/.*"state"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_RUN_FILE"
    elif [ -f "$STATE_DB_FILE" ]; then
        sed -n 's/.*"state"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATE_DB_FILE"
    else
        echo "UNKNOWN"
    fi
}

# 当前传输层模式（transport_manager.sh 维护）：文件缺失/读取失败/未知值一律按普通代理处理
transport_mode_now() {
    _tmode="$(cat "$TRANSPORT_MODE_FILE" 2>/dev/null || true)"
    case "$_tmode" in
        transparent) echo "transparent" ;;
        *) echo "proxy" ;;
    esac
}

port_listening() {
    # $1 = port
    sockstat -4 -l -p "$1" 2>/dev/null | grep -q "$1" || sockstat -4 -l 2>/dev/null | grep -q "127.0.0.1:$1"
}

trigger_failopen() {
    reason="$1"
    log "CRITICAL: Triggering Fail-Open bypass -> Reason: $reason"

    # 透明代理模式：先清空 transport anchor 恢复直连，防 route-to 指向即将停止的 7891 死端口。
    # 无条件执行（幂等）：anchor 为空时无副作用；只操作本插件 anchor，绝不碰主规则集。
    pfctl -a mihomo-transport -F all 2>/dev/null || true
    log "Cleared mihomo-transport anchor: LAN traffic returns to direct routing."

    # 停止进程、清理状态（socks 模式下无 TUN/DNS 残留需要清理）
    if [ -x "$SERVICE_MGR" ]; then
        "$SERVICE_MGR" failopen "$reason" || true
    fi

    log "SUCCESS: Fail-Open completed! mihomo-transport anchor cleared; LAN DNS falls back via AdGuardHome upstream fallback; DIRECT traffic unaffected."
}

CURR_STATE="$(get_current_state)"

case "$CURR_STATE" in
    DISABLED|STOPPED|STOPPING|FAILED)
        # 期望的非代理状态；DNS 已回退，无动作
        exit 0
        ;;
    RUNNING|DEGRADED)
        ;;
    STARTING)
        # 启动宽限：进程活着就再等下一轮巡检，避免慢启动误判
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE" 2>/dev/null || echo 0)" 2>/dev/null; then
            exit 0
        fi
        ;;
    *)
        # 未知状态（如 /var/run 状态文件因重启丢失）：只要 PID 文件不存在就不动作
        if [ ! -f "$PID_FILE" ]; then
            exit 0
        fi
        ;;
esac

# 1. Process alive check
if [ ! -f "$PID_FILE" ]; then
    trigger_failopen "Mihomo PID file missing while in $CURR_STATE state"
    exit 1
fi

PID="$(cat "$PID_FILE" 2>/dev/null || echo "")"
if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    trigger_failopen "Mihomo process (PID: $PID) is dead/crashed"
    exit 1
fi

# 2. API health check (127.0.0.1:9090)
API_OK=0
if command -v curl >/dev/null 2>&1; then
    if curl -s -m 3 --connect-timeout 2 http://127.0.0.1:9090/ >/dev/null 2>&1; then
        API_OK=1
    fi
elif command -v nc >/dev/null 2>&1; then
    if nc -z -w 2 127.0.0.1 9090 2>/dev/null; then
        API_OK=1
    fi
else
    API_OK=1
fi

if [ "$API_OK" -eq 0 ]; then
    trigger_failopen "Mihomo local API (127.0.0.1:9090) is unresponsive"
    exit 1
fi

# 3. DNS listener check (127.0.0.1:1053) —— AdGuardHome 上游指向此端口，属关键依赖
if ! port_listening 1053; then
    trigger_failopen "Mihomo DNS listener (127.0.0.1:1053) is down"
    exit 1
fi

# 4. Transport check: tun 模式查接口；socks 模式查 7891
if tun_enabled; then
    if command -v ifconfig >/dev/null 2>&1; then
        if ! ifconfig "$TUN_DEV" >/dev/null 2>&1; then
            trigger_failopen "Virtual interface $TUN_DEV not found in system"
            exit 1
        fi
    fi
else
    if ! port_listening 7891; then
        trigger_failopen "Mihomo socks listener (127.0.0.1:7891) is down"
        exit 1
    fi
fi

# 全部检查通过（进程/API/DNS/传输层均健康，即 mihomo_healthy）：
# 透明代理模式下若 anchor 规则被外部清空（规则数为 0），静默幂等重挂。
if [ "$(transport_mode_now)" = "transparent" ] && [ -x "$TRANSPORT_MGR" ]; then
    ANCHOR_RULES="$(pfctl -a mihomo-transport -sr 2>/dev/null | grep -c . || true)"
    if [ "${ANCHOR_RULES:-0}" -eq 0 ]; then
        "$TRANSPORT_MGR" recover >/dev/null 2>&1 || true
    fi
fi

# All checks passed
exit 0
