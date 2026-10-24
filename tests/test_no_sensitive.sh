#!/bin/sh
set -eu

# test_no_sensitive.sh - 开源前敏感信息工作区门禁
# 依赖 scripts/audit-sensitive.sh；scripts/export-public.sh 产物可用参数指定目录扫描。

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

echo "===> Running sensitive information audit..."

if [ "$#" -gt 0 ]; then
    sh "$ROOT_DIR/scripts/audit-sensitive.sh" "$1"
else
    sh "$ROOT_DIR/scripts/audit-sensitive.sh"
fi

echo "===> Sensitive information audit PASSED"
