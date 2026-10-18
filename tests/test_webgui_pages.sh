#!/bin/sh
set -eu

echo "===> Running WebGUI pages & configd API tests..."

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CTRL_DIR="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/controllers/OPNsense/Mihomo"
VIEW_DIR="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/views/OPNsense/Mihomo"
ACTIONS="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/service/conf/actions.d/actions_mihomo.conf"

# Test 1: 每个 /ui/mihomo/{page} 菜单地址必须有同名页面控制器（Phalcon 路由
# /ui/{module}/{controller} 按控制器文件名解析；挂在 IndexController 上的
# action 不可达，历史上导致 Rules/Status/Logs 三页 Page not found）
echo "--> Test 1: page controllers for every menu URL..."
for page in index rules status logs; do
    if [ "$page" = "index" ]; then
        PAGE_CTRL="$CTRL_DIR/IndexController.php"
    else
        PAGE_CTRL="$CTRL_DIR/$(printf '%s' "$page" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')Controller.php"
    fi
    [ -f "$PAGE_CTRL" ] || { echo "FAIL: missing page controller $PAGE_CTRL (menu /ui/mihomo/$page would 404)"; exit 1; }
    grep -q "function indexAction" "$PAGE_CTRL" || { echo "FAIL: $PAGE_CTRL has no indexAction"; exit 1; }
    [ -f "$VIEW_DIR/$page.volt" ] || { echo "FAIL: missing view $VIEW_DIR/$page.volt"; exit 1; }
    echo "  [PASS] /ui/mihomo/$page -> $(basename "$PAGE_CTRL") + $page.volt"
done

# Test 2: 菜单 URL 与页面控制器一一对应
MENU_XML="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/models/OPNsense/Mihomo/Menu/Menu.xml"
echo "--> Test 2: menu URLs..."
for page in "" rules status logs; do
    grep -q "url=\"/ui/mihomo/$page\"" "$MENU_XML" || {
        echo "FAIL: menu URL /ui/mihomo/$page not registered"; exit 1;
    }
done
echo "  [PASS] Menu.xml registers /ui/mihomo/, /rules/, /status/, /logs/"

# Test 3: 26.7 configd API 回归守卫 —— configdRun 第二参是 detach（bool），
# 传数组会变成 detach=true，configd 走异步 execute 只返回 job UUID
echo "--> Test 3: no configdRun() with array second argument..."
if grep -rn -E "configdRun\([^)]*,[[:space:]]*(array\(|\[)" \
    "$CTRL_DIR/Api" "$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/models" >/dev/null 2>&1; then
    echo "FAIL: configdRun() called with array second argument (26.7 signature: configdRun(event, detach)); use configdpRun(event, params)"; exit 1
fi
echo "  [PASS] no array-typed configdRun second argument"

# Test 4: 需要传参的调用必须走 configdpRun
echo "--> Test 4: parameterized configd calls use configdpRun..."
grep -q "configdpRun" "$CTRL_DIR/Api/SubscriptionController.php" || {
    echo "FAIL: SubscriptionController must use configdpRun for sub-env-write/setup-cron"; exit 1;
}
echo "  [PASS] configdpRun in use"

# Test 5: 密钥管理闭环 —— configd 动作、脚本子命令与 API action 齐备
echo "--> Test 5: secret management wiring..."
grep -q "^\[secret-set\]" "$ACTIONS" || { echo "FAIL: actions_mihomo.conf missing [secret-set]"; exit 1; }
grep -q "^\[secret-get\]" "$ACTIONS" || { echo "FAIL: actions_mihomo.conf missing [secret-get]"; exit 1; }
grep -q "^\[secret-generate\]" "$ACTIONS" || { echo "FAIL: actions_mihomo.conf missing [secret-generate]"; exit 1; }
grep -q "function secretRevealAction" "$CTRL_DIR/Api/GeneralController.php" || {
    echo "FAIL: GeneralController missing secretRevealAction"; exit 1;
}
grep -q "function secretSetAction" "$CTRL_DIR/Api/GeneralController.php" || {
    echo "FAIL: GeneralController missing secretSetAction"; exit 1;
}
grep -q "secret_manager.sh set" "$ACTIONS" || { echo "FAIL: [secret-set] must call secret_manager.sh set"; exit 1; }
echo "  [PASS] secret-set/secret-get/secret-generate actions + API endpoints wired"

# Test 5b: configd 动作格式守卫 —— %s 只能出现在 parameters: 模板行；
# command 行里的 %s 会被原样传给脚本（字面 %s 占住 argv，参数整体错位，
# 表现为 Execute error / exit 64）
echo "--> Test 5b: no %s placeholders in action command lines..."
if grep -E "^command:.*%s" "$ACTIONS" | grep -q .; then
    grep -E "^command:.*%s" "$ACTIONS" | while read -r line; do echo "  BAD: $line"; done
    echo "FAIL: action command lines must not contain %s (use the parameters: template)"; exit 1
fi
echo "  [PASS] all action parameters live in parameters: templates"

# Test 7: v1.0.7 安全加固守卫
echo "--> Test 7: v1.0.7 security and robustness guards..."
# ① ACL.xml 的 general 组含 ui/mihomo、ui/mihomo/、api/mihomo/service/* 与 api/mihomo/subscription/*
ACL_XML="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/models/OPNsense/Mihomo/ACL/ACL.xml"
[ -f "$ACL_XML" ] || { echo "FAIL: missing ACL.xml"; exit 1; }
awk '
    /<page-services-mihomo-general>/ { in_gen = 1 }
    in_gen && /<pattern>ui\/mihomo<\/pattern>/ { has_ui_exact = 1 }
    in_gen && /<pattern>ui\/mihomo\/<\/pattern>/ { has_ui_slash = 1 }
    in_gen && /<pattern>api\/mihomo\/service\/\*<\/pattern>/ { has_svc = 1 }
    in_gen && /<pattern>api\/mihomo\/subscription\/\*<\/pattern>/ { has_sub = 1 }
    in_gen && /<\/page-services-mihomo-general>/ { closed = 1; exit }
    END {
        if (!in_gen || !closed || !has_ui_exact || !has_ui_slash || !has_svc || !has_sub) {
            exit 1
        }
    }
' "$ACL_XML" || { echo "FAIL: ACL.xml general group must contain ui/mihomo, ui/mihomo/, api/mihomo/service/* and api/mihomo/subscription/*"; exit 1; }
echo "  [PASS] ACL.xml general group contains ui/mihomo, ui/mihomo/, api/mihomo/service/* and api/mihomo/subscription/*"

# ② LogsController.php 含 configdpRun 且不含 "mihomo log ' ." 拼接
LOGS_CTRL="$CTRL_DIR/Api/LogsController.php"
[ -f "$LOGS_CTRL" ] || { echo "FAIL: missing LogsController.php"; exit 1; }
grep -q "configdpRun('mihomo log'" "$LOGS_CTRL" || {
    echo "FAIL: LogsController.php must use configdpRun('mihomo log', ...)"; exit 1;
}
if grep -E "configdRun\(['\"]mihomo log[[:space:]]*['\"][[:space:]]*\." "$LOGS_CTRL" >/dev/null 2>&1; then
    echo "FAIL: LogsController.php must not concatenate configdRun('mihomo log ' .)"; exit 1;
fi
echo "  [PASS] LogsController uses configdpRun without string concatenation"

# ③ GeneralController.php 的 secretRevealAction 含 isPost 校验
GEN_CTRL="$CTRL_DIR/Api/GeneralController.php"
[ -f "$GEN_CTRL" ] || { echo "FAIL: missing GeneralController.php"; exit 1; }
awk '
    /function secretRevealAction/ { in_fn = 1 }
    in_fn && /isPost\(\)/ { has_post = 1 }
    in_fn && /^    \}/ {
        if (!has_post) { exit 1 }
        exit 0
    }
' "$GEN_CTRL" || { echo "FAIL: GeneralController secretRevealAction must check isPost()"; exit 1; }
echo "  [PASS] GeneralController secretRevealAction checks isPost()"

# ④ GeneralController.php 含 getModelNodes 覆盖
grep -q "function getModelNodes" "$GEN_CTRL" || {
    echo "FAIL: GeneralController must override getModelNodes()"; exit 1;
}
echo "  [PASS] GeneralController overrides getModelNodes()"

# Test 8: PHP 语法检查（有 php 时）
echo "--> Test 8: PHP syntax..."
if command -v php >/dev/null 2>&1; then
    for php_file in "$CTRL_DIR"/*.php "$CTRL_DIR"/Api/*.php; do
        php -l "$php_file" >/dev/null || { echo "FAIL: PHP syntax error in $php_file"; exit 1; }
    done
    echo "  [PASS] all controller PHP files lint clean"
else
    echo "  [SKIP] php not available"
fi

echo "===> WebGUI pages & configd API tests PASSED 100%!"
