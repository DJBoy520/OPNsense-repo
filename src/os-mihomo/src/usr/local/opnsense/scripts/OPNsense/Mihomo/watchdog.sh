#!/bin/sh
set -eu

# Mihomo fail-open watchdog (socks-core mode)
# 探测对象：进程 / API(9090) / DNS(1053) / 传输层(tun 模式查 tun_mihomo，socks 模式查 7891 监听)
# 本模式不修改 Unbound、不操作 PF —— 触发 fail-open 仅停掉 mihomo，
# DNS 由 AdGuardHome 的 fallback 上游自然回退，直连流量不受影响。

STATE_RUN_FILE="/var/run/mihomo_state.json"
STATE_DB_FILE="/var/db/os-mihomo/state.json"
PID_FILE="/var/run/mihomo.pid"
LOG_FILE="/var/log/mihomo_watchdog.log"
CONFIG_FILE="/usr/local/etc/mihomo/config.yaml"
SERVICE_MGR="/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh"
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

port_listening() {
    # $1 = port
    sockstat -4 -l -p "$1" 2>/dev/null | grep -q "$1" || sockstat -4 -l 2>/dev/null | grep -q "127.0.0.1:$1"
}

trigger_failopen() {
    reason="$1"
    log "CRITICAL: Triggering Fail-Open bypass -> Reason: $reason"

    # 停止进程、清理状态（socks 模式下无 TUN/anchor/DNS 残留需要清理）
    if [ -x "$SERVICE_MGR" ]; then
        "$SERVICE_MGR" failopen "$reason" || true
    fi

    log "SUCCESS: Fail-Open completed! LAN DNS falls back via AdGuardHome upstream fallback; DIRECT traffic unaffected."
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

# All checks passed
exit 0
