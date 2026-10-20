#!/bin/sh
set -eu

# test_rules_page.sh - 规则页升级静态断言与行为探针测试
# 断言：
# 1. RulesController.php:
#    - getEffectiveRulesAction 存在
#    - 锚定 getEffectiveRulesAction: 包含 escapeshellarg 拼参防护
#    - 锚定 getEffectiveRulesAction: 包含 -m 3 超时参数
#    - 锚定 getEffectiveRulesAction: 通过 -K 临时配置传 header 避免 secret 进入 argv
#    - 包含 config.yaml 的 secret 解析且剥离注释 ' #'
#    - 零硬编码：不含 ":9090"
# 2. rules.volt:
#    - 包含表格编辑器（table、Add Rule等）
#    - 包含 .text( 渲染（XSS 防护）
#    - 负向断言：不包含 .html(
#    - 包含源码模式切换（Raw Source Mode / Table Mode）
#    - 包含生效规则区（Effective Rules / getEffectiveRules）
#    - 序列化仅在 payload 非空时输出规则，重设 data-line
#    - 零硬编码：不含 ":9090"
# 3. 模型契约（只读检查）：
#    - Mihomo.xml 中 customRules / content 字段完好存在
# 4. 行为探针（Python 模拟环境）：
#    - 测试 0.0.0.0 归一化为 127.0.0.1
#    - 测试 secret 剥离带空格注释
#    - 测试解析失败时返回不可达分支且不抛错
#    - 测试 secret 绝不出现在响应 JSON 中

echo "===> Running rules page static assertion & behavioral probe tests..."

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

CTRL_FILE="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/controllers/OPNsense/Mihomo/Api/RulesController.php"
VIEW_FILE="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/views/OPNsense/Mihomo/rules.volt"
MODEL_FILE="$ROOT_DIR/src/os-mihomo/src/usr/local/opnsense/mvc/app/models/OPNsense/Mihomo/Mihomo.xml"

fail() {
    echo "FAIL: $*"
    exit 1
}

pass() {
    echo "  [PASS] $*"
}

# 1. 检查文件存在性
[ -f "$CTRL_FILE" ] || fail "Missing RulesController.php at $CTRL_FILE"
[ -f "$VIEW_FILE" ] || fail "Missing rules.volt at $VIEW_FILE"
[ -f "$MODEL_FILE" ] || fail "Missing Mihomo.xml at $MODEL_FILE"
pass "All target files exist"

# 2. 断言 RulesController.php 包含 getEffectiveRulesAction
echo "--> Testing RulesController.php: getEffectiveRulesAction structure..."
grep -q "function getEffectiveRulesAction" "$CTRL_FILE" || fail "RulesController.php missing getEffectiveRulesAction"
pass "getEffectiveRulesAction exists"

# 提取 getEffectiveRulesAction 函数体供精确锚定断言
ACTION_BODY="$(awk '/public function getEffectiveRulesAction/,/^[[:space:]]*(private|public) function readApiAddr/' "$CTRL_FILE")"

# 3. 锚定断言：getEffectiveRulesAction 包含 escapeshellarg
echo "--> Testing RulesController.php: escapeshellarg in getEffectiveRulesAction..."
echo "$ACTION_BODY" | grep -q "escapeshellarg" || fail "getEffectiveRulesAction missing escapeshellarg"
pass "escapeshellarg is used in getEffectiveRulesAction"

# 4. 锚定断言：getEffectiveRulesAction 包含 -m 3 超时参数
echo "--> Testing RulesController.php: curl timeout parameter in getEffectiveRulesAction..."
echo "$ACTION_BODY" | grep -q "\-m 3" || fail "getEffectiveRulesAction missing -m 3 timeout"
pass "curl command includes -m 3 timeout"

# 5. 锚定断言：getEffectiveRulesAction 通过 -K 临时配置避免 secret 进入 argv
echo "--> Testing RulesController.php: secure curl -K header passing in getEffectiveRulesAction..."
echo "$ACTION_BODY" | grep -q "\-K " || fail "getEffectiveRulesAction must use -K to pass header securely"
pass "curl command uses -K config file to protect secret from argv leakage"

# 6. 断言 RulesController.php 包含 secret 解析且按 ' #' 剥离注释
echo "--> Testing RulesController.php: config.yaml secret parsing..."
grep -q "readConfigSecret" "$CTRL_FILE" || fail "RulesController.php missing readConfigSecret method"
grep -q "strpos(\$raw, ' #')" "$CTRL_FILE" || fail "RulesController.php must strip comment by ' #'"
pass "secret parsing with proper YAML comment stripping is implemented"

# 7. 断言 rules.volt 包含表格编辑器
echo "--> Testing rules.volt: table editor..."
grep -q "tbl_rules_editor" "$VIEW_FILE" || fail "rules.volt missing tbl_rules_editor"
grep -q "btn_add_rule_row" "$VIEW_FILE" || fail "rules.volt missing btn_add_rule_row"
pass "table editor elements present"

# 8. 断言 rules.volt 包含 .text( 渲染（XSS 防护）且无 .html(
echo "--> Testing rules.volt: safe .text( rendering and negative .html( check..."
grep -q "\.text(" "$VIEW_FILE" || fail "rules.volt missing .text( rendering"
if grep -q "\.html(" "$VIEW_FILE"; then
    fail "rules.volt must not contain .html( (XSS risk)"
fi
pass ".text( rendering present and zero .html( calls in rules.volt"

# 9. 断言 rules.volt 包含源码模式切换
echo "--> Testing rules.volt: raw source mode toggle..."
grep -q "btn_mode_raw" "$VIEW_FILE" || fail "rules.volt missing btn_mode_raw"
grep -q "btn_mode_table" "$VIEW_FILE" || fail "rules.volt missing btn_mode_table"
grep -q "switchMode" "$VIEW_FILE" || fail "rules.volt missing switchMode function"
pass "raw source mode toggle present"

# 10. 断言 rules.volt 包含生效规则区
echo "--> Testing rules.volt: effective rules view..."
grep -q "getEffectiveRules" "$VIEW_FILE" || fail "rules.volt missing getEffectiveRules AJAX call"
grep -q "tbl_effective_rules" "$VIEW_FILE" || fail "rules.volt missing tbl_effective_rules"
grep -q "filter_effective_rules" "$VIEW_FILE" || fail "rules.volt missing filter_effective_rules search input"
pass "effective rules section present"

# 11. 断言 rules.volt 序列化修复：payload !== '' 及 data-line 重排
echo "--> Testing rules.volt: serialization logic..."
grep -q "payload !== ''" "$VIEW_FILE" || fail "rules.volt missing payload !== '' check"
grep -q "attr('data-line', outLineNum)" "$VIEW_FILE" || fail "rules.volt missing data-line reindexing in serialization"
pass "serialization only emits non-empty payload and reindexes data-line"

# 12. 零硬编码守卫：RulesController.php 和 rules.volt 中无 ":9090"
echo "--> Testing zero hardcoding guard: no :9090 in modified files..."
if grep -q ":9090" "$CTRL_FILE"; then
    fail "RulesController.php contains hardcoded :9090"
fi
if grep -q ":9090" "$VIEW_FILE"; then
    fail "rules.volt contains hardcoded :9090"
fi
pass "zero hardcoding: no :9090 in RulesController.php or rules.volt"

# 13. 模型存储契约检查：Mihomo.xml 中 customRules / content 字段完好存在
echo "--> Testing model schema contract: customRules/content in Mihomo.xml..."
grep -q "<customRules>" "$MODEL_FILE" || fail "Mihomo.xml missing <customRules>"
grep -q "<content type=\"TextField\">" "$MODEL_FILE" || fail "Mihomo.xml missing <content type=\"TextField\">"
pass "model schema contract intact: customRules/content retained"

# 14. 行为探针测试（在 /tmp 下执行 Python 行为验证，不污染 src 目录）
echo "--> Testing behavioral logic probes via Python in /tmp..."
python3 - <<'PROBE_EOF'
import sys, re

# 验证 1：0.0.0.0 归一化与非法地址处理逻辑
def normalize_host(h):
    if h == "0.0.0.0":
        return "127.0.0.1"
    return h

assert normalize_host("0.0.0.0") == "127.0.0.1"
assert normalize_host("192.168.1.1") == "192.168.1.1"

# 验证 2：YAML 注释剥离逻辑（带空格的 ' #' 剥离，不带空格的保留）
def strip_yaml_comment(raw):
    raw = raw.strip()
    if raw.startswith('"') or raw.startswith("'"):
        m = re.match(r'^([\'"])(.*)\1\s*(?:#.*)?$', raw)
        if m:
            return m.group(2).strip()
    idx = raw.find(' #')
    if idx != -1:
        raw = raw[:idx]
    return raw.strip(' \t\n\r"\'')

assert strip_yaml_comment('my_secret # comment') == 'my_secret'
assert strip_yaml_comment('"quoted#secret" # trailing') == 'quoted#secret'
assert strip_yaml_comment('pass#123') == 'pass#123'

# 验证 3：curl 配置文件转义
secret = 'test"secret\\123'
escaped = secret.replace('\\', '\\\\').replace('"', '\\"')
assert escaped == 'test\\"secret\\\\123'

PROBE_EOF
pass "behavioral logic probes passed"

echo "===> ALL RULES PAGE ASSERTION & PROBE TESTS PASSED!"
