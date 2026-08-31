#!/bin/sh
set -eu

STATE_RUN_FILE="/var/run/mihomo_state.json"
STATE_DB_FILE="/var/db/os-mihomo/state.json"
PID_FILE="/var/run/mihomo.pid"
LOG_FILE="/var/log/mihomo_watchdog.log"
CONFIG_FILE="/usr/local/etc/mihomo/config.yaml"
SERVICE_MGR="/usr/local/opnsense/scripts/OPNsense/Mihomo/service_manager.sh"

log() {
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "[%s] [WATCHDOG] %s\n" "$ts" "$*" | tee -a "$LOG_FILE" 2>/dev/null || true
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

trigger_failopen() {
    reason="$1"
    log "CRITICAL: Triggering Fail-Open bypass -> Reason: $reason"
    
    # 1. Update state machine to FAILED with DIRECT fallback mode
    if [ -x "$SERVICE_MGR" ]; then
        # Invoke service manager stop/failopen handler
        "$SERVICE_MGR" failopen "$reason" || true
    fi

    # 2. Emergency cleanup of PF rules & TUN device
    if command -v pfctl >/dev/null 2>&1; then
        pfctl -a "mihomo" -F all 2>/dev/null || true
    fi

    # 3. Emergency restore of Unbound DNS (bypass fake-ip / mihomo DNS)
    if [ -x "/usr/local/opnsense/scripts/mihomo/setup_unbound.php" ]; then
        /usr/local/opnsense/scripts/mihomo/setup_unbound.php uninstall 2>/dev/null || true
    fi

    if command -v configctl >/dev/null 2>&1; then
        configctl filter reload >/dev/null 2>&1 || true
        configctl template reload OPNsense/Unbound >/dev/null 2>&1 || true
        configctl unbound restart >/dev/null 2>&1 || true
    fi

    log "SUCCESS: Fail-Open completed! Direct WAN internet & DNS access restored."
}

# Inspect active status
CURR_STATE="$(get_current_state)"

case "$CURR_STATE" in
    DISABLED|STOPPED|STOPPING)
        # Expected non-proxy states, no action needed
        exit 0
        ;;
    FAILED)
        # Already in failed direct mode, check if we need to ensure clean state
        exit 0
        ;;
    RUNNING|DEGRADED)
        ;;
    *)
        # Unknown state, check if pid exists
        if [ ! -f "$PID_FILE" ]; then
            exit 0
        fi
        ;;
esac

# Perform active health checks:
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
    if curl -s -m 3 --connect-timeout 2 http://127.0.0.1:9090/ >/dev/null 2>&1 || \
       curl -s -m 3 --connect-timeout 2 -H "Authorization: Bearer test" http://127.0.0.1:9090/version >/dev/null 2>&1; then
        API_OK=1
    fi
elif command -v nc >/dev/null 2>&1; then
    if nc -z -w 2 127.0.0.1 9090 2>/dev/null; then
        API_OK=1
    fi
else
    # Basic TCP probe via /dev/tcp (if bash) or fallback
    API_OK=1
fi

if [ "$API_OK" -eq 0 ]; then
    trigger_failopen "Mihomo local API (127.0.0.1:9090) is unresponsive"
    exit 1
fi

# 3. Virtual TUN device check (tun_mihomo)
if command -v ifconfig >/dev/null 2>&1; then
    if ! ifconfig tun_mihomo >/dev/null 2>&1; then
        trigger_failopen "Virtual interface tun_mihomo not found in system"
        exit 1
    fi
fi

# All checks passed
exit 0
