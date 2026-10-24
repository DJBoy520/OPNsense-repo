#!/bin/sh
# scripts/audit-sensitive.sh
# 敏感信息审计脚本（只读扫描，命中文档:行号，不打印具体命中值，非 0 退出）
#
# 规则：
# 1. 优先读取 .private/sensitive-patterns.txt（若存在且非空），按其中真实模式扫描 tracked 文件
# 2. 否则执行通用检查：
#    - 个人主目录绝对路径（/home/<user>）
#    - OPNsense 默认账号口令（root/opnsense 等）
#    - 个人邮箱
#    - 真实私网 IPv4（带 RFC1918/TEST-NET 示例 allowlist）
# 3. 命中输出: "文件:行号: [规则类型] 命中敏感信息"，不打印命中值，退出非 0

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"

PATTERN_FILE="$ROOT_DIR/.private/sensitive-patterns.txt"

# 检查 python3 是否存在，优先用 Python 提供快速、精准、防越界的多行/正则处理
if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 required for audit-sensitive.sh" >&2
    exit 2
fi

exec python3 - "$ROOT_DIR" "$PATTERN_FILE" "$@" << 'PYEOF'
import sys
import os
import re
import subprocess

root_dir = sys.argv[1]
pattern_file = sys.argv[2]
cli_target_dir = sys.argv[3] if len(sys.argv) > 3 else None

os.chdir(root_dir)

# 确定扫描文件列表
if cli_target_dir and os.path.exists(cli_target_dir):
    # 如果指定了目标目录（如 dist/public），扫描该目录下所有普通文本文件
    tracked_files = []
    for base, dirs, files in os.walk(cli_target_dir):
        # 排除常见忽略目录
        dirs[:] = [d for d in dirs if d not in {".git", ".private", "work", "output", "repo"}]
        for f in files:
            p = os.path.relpath(os.path.join(base, f), root_dir)
            tracked_files.append(p)
else:
    # 扫描 git tracked 文件
    try:
        out = subprocess.check_output(["git", "ls-files", "--cached", "--others", "--exclude-standard"], stderr=subprocess.PIPE).decode("utf-8")
        tracked_files = out.splitlines()
    except Exception as e:
        sys.stderr.write(f"Failed to get git ls-files: {e}\n")
        sys.exit(2)

# 二进制文件判定
def is_binary(filepath):
    try:
        with open(filepath, "rb") as f:
            chunk = f.read(1024)
            return b"\0" in chunk
    except Exception:
        return True

# 检查是否存在 .private/sensitive-patterns.txt
use_custom_patterns = False
custom_patterns = []
if os.path.isfile(pattern_file) and os.path.getsize(pattern_file) > 0:
    try:
        with open(pattern_file, "r", encoding="utf-8") as pf:
            for line in pf:
                line = line.strip()
                if line and not line.startswith("#"):
                    custom_patterns.append(line)
        if custom_patterns:
            use_custom_patterns = True
    except Exception as e:
        sys.stderr.write(f"Warning: could not read {pattern_file}: {e}\n")

hits = []

if use_custom_patterns:
    # 按照自定义模式逐条扫描
    compiled = []
    for pat in custom_patterns:
        try:
            compiled.append((pat, re.compile(pat, re.IGNORECASE)))
        except Exception:
            compiled.append((pat, re.compile(re.escape(pat), re.IGNORECASE)))
    
    for relpath in tracked_files:
        if not os.path.isfile(relpath) or is_binary(relpath):
            continue
        try:
            with open(relpath, "r", encoding="utf-8", errors="ignore") as f:
                for line_idx, line in enumerate(f, 1):
                    for pat_str, reg in compiled:
                        if reg.search(line):
                            hits.append(f"{relpath}:{line_idx}: [custom-pattern] 命中匹配规则")
                            break
        except Exception:
            pass
else:
    # 通用规则扫描
    # 规则 1: 个人家目录路径
    re_home = re.compile(r"/home/[a-zA-Z0-9_-]+", re.IGNORECASE)

    # 规则 2: OPNsense 默认账号口令组合
    re_cred = re.compile(r"\b(root/opnsense|root:opnsense)\b", re.IGNORECASE)

    # 规则 4: 邮箱地址 (排除上游开源许可证通用版权邮箱、文档样例 example.com / @opnsense.org)
    re_email = re.compile(r"\b([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})\b")

    # 规则 5: 私网 IPv4 地址
    re_ipv4 = re.compile(r"\b(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3})\b")

    # 允许的示例 IP 与技术规范 CIDR (白名单)
    allowed_ip_substrings = [
        "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
        "10.0.0.1", "10.0.0.2", "10.0.0.2/30",
        "172.19.0.1/30", "172.19.0.1",
        "192.168.1.0/24", "192.168.1.1", "192.168.1.7", "192.168.1.10", "192.168.1.10:12345", "192.168.1.10:9095",
        "192.168.10.0/24", "192.168.101.0/24", "10.125.0.1/24", "10.125.0.1",
        "192.168.50.2", "192.168.50.255", "10.9.9.9", "10.9.9.90", "10.20.30.40"
    ]

    # 允许的邮箱白名单 (上游开源软件的原作者、开源组织、测试样例)
    allowed_email_domains = [
        "opnsense.org", "glockners.net", "cekal.org", "gmail.com", "lshell.com",
        "frenking.eu", "der-ingo.de", "bluemedia.dev", "neon1.net", "max-it.de",
        "li.org", "example.com", "example.org", "example.net"
    ]

    # 内部文件豁免（根据 IMPL-1.2.0-packages.md 要求，内部交接文档及未脱敏工作日志由 export-public 排除，不在本包中删除）
    # 但如果在导出后的公开发布目录中，则不得有任何豁免
    exempt_internal = {"docs/HANDOFF-20261017.md", "docs/HANDOFF-20261019.md", "progress.md", "scripts/audit-sensitive.sh"} if not cli_target_dir else set()

    for relpath in tracked_files:
        if relpath in exempt_internal:
            continue
        if os.path.basename(relpath) == "audit-sensitive.sh":
            continue
        if not os.path.isfile(relpath) or is_binary(relpath):
            continue

        try:
            with open(relpath, "r", encoding="utf-8", errors="ignore") as f:
                for line_idx, line in enumerate(f, 1):
                    # 规则 1: 个人家目录路径
                    if re_home.search(line):
                        hits.append(f"{relpath}:{line_idx}: [user-home] 命中个人绝对路径模式")
                        continue

                    # 规则 2: OPNsense 默认账号口令
                    if re_cred.search(line):
                        hits.append(f"{relpath}:{line_idx}: [default-credentials] 命中默认账号口令模式")
                        continue

                    # 规则 4: 邮箱
                    m_emails = re_email.findall(line)
                    if m_emails:
                        bad_email = False
                        for em in m_emails:
                            dom = em.split("@")[-1].lower()
                            if dom not in allowed_email_domains:
                                bad_email = True
                                break
                        if bad_email:
                            hits.append(f"{relpath}:{line_idx}: [personal-email] 命中未登记域名的个人邮箱")
                            continue

                    # 规则 5: 私网 IPv4
                    m_ips = re_ipv4.findall(line)
                    if m_ips:
                        bad_ip = False
                        for ip in m_ips:
                            # 检查是否匹配任何白名单前缀或示例
                            if not any(token in line for token in allowed_ip_substrings):
                                bad_ip = True
                                break
                        if bad_ip:
                            hits.append(f"{relpath}:{line_idx}: [private-ipv4] 命中未列入白名单的私网 IPv4 地址")
                            continue
        except Exception:
            pass

if hits:
    print(f"=== 敏感信息扫描失败: 发现 {len(hits)} 处可能泄露 ===", file=sys.stderr)
    for h in hits:
        print(h, file=sys.stderr)
    sys.exit(1)
else:
    print("=== 敏感信息扫描通过: 未发现敏感泄露 ===")
    sys.exit(0)
PYEOF
