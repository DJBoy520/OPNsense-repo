#!/bin/sh
set -eu

# service_manager.sh - Mihomo 7-State Lifecycle State Machine Manager
# States: DISABLED, STARTING, RUNNING, DEGRADED, STOPPING, STOPPED, FAILED
# Modes: PROXY, DIRECT

STATE_FILE="/var/run/mihomo_state.json"
STATE_DB_DIR="/var/db/os-mihomo"
STATE_DB_FILE="${STATE_DB_DIR}/state.json"

NAME="mihomo"
BIN="/usr/local/bin/mihomo"
CONF_DIR="/usr/local/etc/mihomo"
CONF_FILE="${CONF_DIR}/config.yaml"
PID_FILE="/var/run/mihomo.pid"
LOG_FILE="/var/log/mihomo.log"
TUN_DEV="tun_mihomo"
API_URL="http://127.0.0.1:9090"
API_TIMEOUT=30

mkdir -p /var/run "${STATE_DB_DIR}" 2>/dev/null || true

get_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S"
}

set_state() {
    _state="$1"
    _mode="$2"
    _pid="$3"
    _msg="$4"
    _ts="$(get_timestamp)"

    _pid_json="null"
    if [ -n "${_pid}" ] && [ "${_pid}" != "null" ]; then
        _pid_json="${_pid}"
    fi

    # Escape quotes in message if needed
    _msg_escaped="$(printf '%s' "${_msg}" | sed 's/"/\\"/g')"

    _json=$(cat <<EOF
{
  "state": "${_state}",
  "mode": "${_mode}",
  "pid": ${_pid_json},
  "last_change": "${_ts}",
  "message": "${_msg_escaped}"
}
EOF
)
    printf '%s\n' "${_json}" > "${STATE_FILE}.tmp"
    mv -f "${STATE_FILE}.tmp" "${STATE_FILE}"
    cp -f "${STATE_FILE}" "${STATE_DB_FILE}" 2>/dev/null || true
}

get_current_pid() {
    if [ -f "${PID_FILE}" ]; then
        _dpid="$(cat "${PID_FILE}" 2>/dev/null || true)"
        if [ -n "${_dpid}" ] && kill -0 "${_dpid}" 2>/dev/null; then
            _mpid="$(pgrep -P "${_dpid}" mihomo 2>/dev/null | head -n 1 || true)"
            if [ -n "${_mpid}" ] && kill -0 "${_mpid}" 2>/dev/null; then
                echo "${_mpid}"
                return 0
            fi
            echo "${_dpid}"
            return 0
        fi
    fi
    _cpid="$(pgrep -f "${BIN} -d ${CONF_DIR}" 2>/dev/null | head -n 1 || true)"
    if [ -n "${_cpid}" ] && kill -0 "${_cpid}" 2>/dev/null; then
        echo "${_cpid}"
        return 0
    fi
    echo ""
}

cleanup_routing_and_pf() {
    # Destroy TUN interface if exists
    if ifconfig "${TUN_DEV}" >/dev/null 2>&1; then
        ifconfig "${TUN_DEV}" destroy 2>/dev/null || true
    fi

    # Clear stale routes if added
    # Mihomo strict-route/auto-route usually cleans up on normal stop, but on crash or failure ensure fallback
    # In OPNsense, DIRECT mode is normal default gateway routing without TUN
}

check_api_ready() {
    _elapsed=0
    while [ "${_elapsed}" -lt "${API_TIMEOUT}" ]; do
        if curl -s -m 2 "${API_URL}" >/dev/null 2>&1; then
            return 0
        fi
        if sockstat -4 -l -p 9090 2>/dev/null | grep -q 9090; then
            return 0
        fi
        sleep 1
        _elapsed=$((_elapsed + 1))
    done
    return 1
}

check_tun_ready() {
    if ifconfig "${TUN_DEV}" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

do_start() {
    # Check if disabled
    if [ -f /etc/rc.conf.d/mihomo ]; then
        . /etc/rc.conf.d/mihomo
        if [ "${mihomo_enable:-YES}" = "NO" ] || [ "${mihomo_enable:-YES}" = "no" ]; then
            set_state "DISABLED" "DIRECT" null "Mihomo is disabled in rc.conf.d"
            echo "Mihomo is disabled in rc.conf.d."
            return 0
        fi
    fi

    # Check sing-box conflict
    if service sing-box status >/dev/null 2>&1; then
        set_state "FAILED" "DIRECT" null "Refusing to start: sing-box is running"
        echo "Refusing to start mihomo: sing-box is already running."
        return 1
    fi

    # 1. Config validation
    if [ ! -f "${CONF_FILE}" ]; then
        cleanup_routing_and_pf
        set_state "FAILED" "DIRECT" null "Configuration file not found: ${CONF_FILE}"
        echo "Configuration file not found: ${CONF_FILE}"
        return 1
    fi

    if ! "${BIN}" -t -d "${CONF_DIR}" -f "${CONF_FILE}" >> "${LOG_FILE}" 2>&1; then
        cleanup_routing_and_pf
        set_state "FAILED" "DIRECT" null "Configuration validation failed"
        echo "Mihomo configuration validation failed."
        return 1
    fi

    # 2. Set STARTING
    set_state "STARTING" "DIRECT" null "Service is starting"

    # Cleanup stale pid/tun before starting
    if [ -f "${PID_FILE}" ]; then
        _old_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
        if [ -n "${_old_pid}" ] && kill -0 "${_old_pid}" 2>/dev/null; then
            echo "Mihomo is already running with PID ${_old_pid}."
            do_healthcheck
            return 0
        fi
        rm -f "${PID_FILE}"
    fi

    if ifconfig "${TUN_DEV}" >/dev/null 2>&1; then
        ifconfig "${TUN_DEV}" destroy 2>/dev/null || true
    fi

    # 3. Start background daemon
    touch "${LOG_FILE}"
    /usr/sbin/daemon -P "${PID_FILE}" -f -o "${LOG_FILE}" -t "${NAME}:daemon" "${BIN}" -d "${CONF_DIR}/"

    # 4. Check process PID
    sleep 1
    _pid="$(get_current_pid)"
    if [ -z "${_pid}" ]; then
        cleanup_routing_and_pf
        set_state "FAILED" "DIRECT" null "Daemon failed to spawn Mihomo process"
        echo "Mihomo failed to start (process missing)."
        return 1
    fi

    # 5. Check API ready (30s timeout)
    if ! check_api_ready; then
        do_stop_internal
        cleanup_routing_and_pf
        set_state "FAILED" "DIRECT" null "API failed to respond within ${API_TIMEOUT}s"
        echo "Mihomo API healthcheck timed out."
        return 1
    fi

    # 6. Check TUN interface
    if ! check_tun_ready; then
        # If API is up but TUN is missing, mark DEGRADED or check if TUN was expected
        set_state "DEGRADED" "DIRECT" "${_pid}" "API is ready but TUN interface ${TUN_DEV} is DOWN"
        echo "Warning: Mihomo started but TUN interface ${TUN_DEV} is not detected."
        return 0
    fi

    # 7. Health check passed -> RUNNING / PROXY
    set_state "RUNNING" "PROXY" "${_pid}" "Service is healthy and operating in PROXY mode"
    echo "Mihomo started successfully (PID ${_pid}, mode PROXY)."
    return 0
}

do_stop_internal() {
    _stopped=0

    if [ -f "${PID_FILE}" ]; then
        _daemon_pid="$(cat "${PID_FILE}" 2>/dev/null || true)"
        if [ -n "${_daemon_pid}" ] && kill -0 "${_daemon_pid}" 2>/dev/null; then
            _child_pids="$(pgrep -P "${_daemon_pid}" mihomo 2>/dev/null || true)"
            if [ -n "${_child_pids}" ]; then
                kill ${_child_pids} 2>/dev/null || true
            fi
            kill "${_daemon_pid}" 2>/dev/null || true
            _stopped=1

            for _ in 1 2 3 4 5 6 7 8 9 10; do
                _still_running=0
                if kill -0 "${_daemon_pid}" 2>/dev/null; then
                    _still_running=1
                fi
                for _p in ${_child_pids}; do
                    if kill -0 "${_p}" 2>/dev/null; then
                        _still_running=1
                        break
                    fi
                done
                [ "${_still_running}" -eq 0 ] && break
                sleep 1
            done

            if kill -0 "${_daemon_pid}" 2>/dev/null; then
                kill -KILL "${_daemon_pid}" 2>/dev/null || true
            fi
            for _p in ${_child_pids}; do
                if kill -0 "${_p}" 2>/dev/null; then
                    kill -KILL "${_p}" 2>/dev/null || true
                fi
            done
        fi
    fi

    _extra_pids="$(pgrep -f "${BIN} -d ${CONF_DIR}" 2>/dev/null || true)"
    if [ -n "${_extra_pids}" ]; then
        kill ${_extra_pids} 2>/dev/null || true
        _stopped=1
        sleep 1
        for _p in ${_extra_pids}; do
            if kill -0 "${_p}" 2>/dev/null; then
                kill -KILL "${_p}" 2>/dev/null || true
            fi
        done
    fi

    rm -f "${PID_FILE}"
    return 0
}

do_stop() {
    _curr_pid="$(get_current_pid)"
    set_state "STOPPING" "DIRECT" "${_curr_pid:-null}" "Service is stopping"

    do_stop_internal
    cleanup_routing_and_pf

    set_state "STOPPED" "DIRECT" null "Service is stopped"
    echo "Mihomo stopped."
    return 0
}

do_restart() {
    do_stop
    sleep 1
    do_start
}

do_reload() {
    _pid="$(get_current_pid)"
    if [ -z "${_pid}" ]; then
        echo "Mihomo is not running, starting instead."
        do_start
        return $?
    fi

    # Validate config before reload
    if ! "${BIN}" -t -d "${CONF_DIR}" -f "${CONF_FILE}" >> "${LOG_FILE}" 2>&1; then
        echo "Config reload aborted: configuration validation failed."
        return 1
    fi

    # Send SIGHUP or use External Controller API reload if available
    # Mihomo reloads config on SIGHUP
    if kill -HUP "${_pid}" 2>/dev/null; then
        echo "Sent SIGHUP to Mihomo (PID ${_pid})."
        sleep 1
        do_healthcheck
        return 0
    else
        echo "Failed to send SIGHUP, restarting."
        do_restart
    fi
}

do_healthcheck() {
    _pid="$(get_current_pid)"
    if [ -z "${_pid}" ]; then
        if [ -f /etc/rc.conf.d/mihomo ]; then
            . /etc/rc.conf.d/mihomo
            if [ "${mihomo_enable:-YES}" = "NO" ] || [ "${mihomo_enable:-YES}" = "no" ]; then
                set_state "DISABLED" "DIRECT" null "Mihomo is disabled"
                echo "Mihomo is disabled."
                return 0
            fi
        fi
        set_state "STOPPED" "DIRECT" null "Mihomo is stopped"
        echo "Mihomo is stopped."
        return 1
    fi

    _tun_ok=0
    _api_ok=0

    if check_tun_ready; then
        _tun_ok=1
    fi

    if curl -s -m 2 "${API_URL}" >/dev/null 2>&1 || sockstat -4 -l -p 9090 2>/dev/null | grep -q 9090; then
        _api_ok=1
    fi

    if [ "${_tun_ok}" -eq 1 ] && [ "${_api_ok}" -eq 1 ]; then
        set_state "RUNNING" "PROXY" "${_pid}" "Healthy (TUN UP, API UP)"
        echo "Mihomo is running (PID ${_pid}, TUN UP, API UP)."
        return 0
    elif [ "${_tun_ok}" -eq 1 ] && [ "${_api_ok}" -eq 0 ]; then
        set_state "DEGRADED" "PROXY" "${_pid}" "Degraded (TUN UP, API DOWN)"
        echo "Mihomo is degraded (PID ${_pid}, TUN UP, API DOWN)."
        return 0
    elif [ "${_tun_ok}" -eq 0 ] && [ "${_api_ok}" -eq 1 ]; then
        set_state "DEGRADED" "DIRECT" "${_pid}" "Degraded (TUN DOWN, API UP)"
        echo "Mihomo is degraded (PID ${_pid}, TUN DOWN, API UP)."
        return 0
    else
        set_state "FAILED" "DIRECT" "${_pid}" "Unhealthy (TUN DOWN, API DOWN)"
        echo "Mihomo is unhealthy (PID ${_pid}, TUN DOWN, API DOWN)."
        return 1
    fi
}

do_status() {
    _pid="$(get_current_pid)"
    if [ -f "${STATE_FILE}" ]; then
        cat "${STATE_FILE}"
        echo ""
    fi

    if [ -n "${_pid}" ]; then
        echo "${NAME} is running as pid ${_pid}."
        return 0
    else
        echo "${NAME} is not running."
        return 1
    fi
}

do_failopen() {
    _reason="${2:-Emergency Fail-Open triggered}"
    _curr_pid="$(get_current_pid)"
    echo "==> Triggering Fail-Open bypass: ${_reason}"
    
    # 1. Terminate any stuck/zombie processes
    do_stop_internal || true
    
    # 2. Cleanup TUN device & routing
    cleanup_routing_and_pf
    
    # 3. Mark state as FAILED in DIRECT fallback mode
    set_state "FAILED" "DIRECT" null "Fail-Open activated: ${_reason}"
    echo "Fail-Open completed. State: FAILED, Mode: DIRECT."
    return 0
}

case "${1:-status}" in
    start)
        do_start
        ;;
    stop)
        do_stop
        ;;
    restart)
        do_restart
        ;;
    reload)
        do_reload
        ;;
    healthcheck)
        do_healthcheck
        ;;
    failopen)
        do_failopen "$@"
        ;;
    status)
        do_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status|healthcheck|failopen}"
        exit 1
        ;;
esac
