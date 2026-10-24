#!/bin/sh
set -eu

echo "===> Running uninstall hygiene gate checks..."

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
POST_DEINSTALL="$ROOT_DIR/src/os-mihomo/packaging/freebsd/+POST_DEINSTALL"
PRE_DEINSTALL="$ROOT_DIR/src/os-mihomo/packaging/freebsd/+PRE_DEINSTALL"

fail() {
    echo "FAIL: $1"
    exit 1
}

# 1. POST_DEINSTALL 必须清理运行时 drop-in（pkg 只删 manifest 文件，以下为运行时生成）
echo "--> Test 1: runtime drop-ins cleaned on uninstall..."
grep -q 'rm -f /etc/cron.d/os-mihomo' "$POST_DEINSTALL" \
    || fail "orphan cron /etc/cron.d/os-mihomo not cleaned in +POST_DEINSTALL"
grep -q 'rm -f /etc/rc.conf.d/mihomo_hev' "$POST_DEINSTALL" \
    || fail "rc.conf.d/mihomo_hev not cleaned in +POST_DEINSTALL"
grep -q 'rm -rf .*__pycache__' "$POST_DEINSTALL" \
    || fail "python __pycache__ not cleaned in +POST_DEINSTALL"
echo "  [PASS] cron drop-in, hev rc.conf.d, pycache cleanup asserted."

# 2. manifest 内嵌脚本的可执行行禁止百分号（会被 pkg 格式化吃掉；注释行不受影响）
echo "--> Test 2: no percent chars in deinstall script code..."
if sed 's/#.*$//' "$POST_DEINSTALL" | grep -q '%'; then
    fail "+POST_DEINSTALL code contains a percent sign (corrupted by pkg manifest embedding)"
fi
if sed 's/#.*$//' "$PRE_DEINSTALL" | grep -q '%'; then
    fail "+PRE_DEINSTALL code contains a percent sign (corrupted by pkg manifest embedding)"
fi
echo "  [PASS] deinstall script code is percent-free."

# 3. 用户配置必须搬移留档而非直接删除
echo "--> Test 3: config archived to /root..."
grep -q 'os-mihomo-removed-' "$POST_DEINSTALL" \
    || fail "config archive mv to /root/os-mihomo-removed-* missing"
echo "  [PASS] config archive behavior asserted."

# 4. POST_INSTALL 必须 bootstrap watchdog cron（全新安装未保存订阅前 fail-open 安全网在场）
echo "--> Test 4: watchdog cron bootstrapped on install..."
POST_INSTALL="$ROOT_DIR/src/os-mihomo/packaging/freebsd/+POST_INSTALL"
grep -q 'mihomo_setup.php --cron-only' "$POST_INSTALL" \
    || fail "+POST_INSTALL does not bootstrap watchdog cron (transparent fail-open net missing on fresh install)"
echo "  [PASS] watchdog cron bootstrap asserted."

# 5. POST_INSTALL 所有 php 调用必须用绝对路径（pkg 脚本环境 PATH 不保证含 /usr/local/bin，
#    裸 php 静默失败曾导致模型 transparent 的升级后传输层不再重挂）
echo "--> Test 5: php invoked by absolute path in POST_INSTALL..."
if grep -E 'php -' "$POST_INSTALL" | grep -vF '/usr/local/bin/php ' | grep -q .; then
    fail "+POST_INSTALL contains bare php invocation (PATH-dependent, silently broken under pkg)"
fi
echo "  [PASS] all php calls absolute."

# 6. POST_INSTALL Step4 的 transport_manager 守卫必须是绝对路径
#    （$CONF_DIR/../opnsense 展开成不存在的 /usr/local/etc/opnsense，transparent 升级后静默不重挂）
echo "--> Test 6: transport_manager guard path in POST_INSTALL Step4..."
if grep -F 'CONF_DIR/../opnsense/scripts/OPNsense/Mihomo/transport_manager.sh' "$POST_INSTALL" | grep -q .; then
    fail "+POST_INSTALL Step4 guard uses CONF_DIR/../opnsense (resolves to nonexistent /usr/local/etc/opnsense)"
fi
grep -qF '[ -x /usr/local/opnsense/scripts/OPNsense/Mihomo/transport_manager.sh ]' "$POST_INSTALL" \
    || fail "+POST_INSTALL Step4 missing absolute transport_manager guard"
echo "  [PASS] guard path absolute."

echo "===> All uninstall hygiene gate checks PASSED."
