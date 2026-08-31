# Secure OPNsense Mihomo 项目推进记录 (Progress Tracker)

> 项目：Secure OPNsense Mihomo Plugin  
> 分支：`secure-mihomo`  
> 基线 Tag：`baseline-opnwall-mihomo`  
> 最近提交：收尾交付 (Phase 0~10 全线完成)  
> 更新时间：2026-08-31  

---

## 阶段执行状态一览

| Phase | 阶段名称 | 状态 | 关键成果与交付物 |
| :--- | :--- | :--- | :--- |
| **Phase 0** | **基线建立与全面审计** | ✅ **已完成** | 建立 `secure-mihomo` 分支与基线 tag；输出 4 份基线与规划文档 (`SECURITY-BASELINE.md`, `ARCHITECTURE-BASELINE.md`, `BUILD-BASELINE.md`, `ROADMAP-P0-P1-P2.md`)。 |
| **Phase 1** | **Ubuntu 可重复构建环境** | ✅ **已完成** | 实现跨平台打包与校验流水线 `scripts/build.sh` 与 `scripts/verify-package.sh`；产出 `output/os-mihomo-*.pkg`、`SHA256SUMS`、`build-info.json`。 |
| **Phase 2** | **Mihomo 官方供应链** | ✅ **已完成** | 锁定 MetaCubeX 官方 v1.19.30 (compatible/v1)；创建 `mihomo-version.env`；实现 `update-mihomo.sh` 与 `check-mihomo-release.sh`；完成 SHA256 与架构校验。 |
| **Phase 3** | **WebGUI 原生 MVC 架构** | ✅ **已完成** | 彻底删除旧面向过程 PHP 文件与未授权日志接口；全面重构为 OPNsense 26.7+ Phalcon MVC（Model, View, Controller, ACL, Menu, Volt 模板）。 |
| **Phase 4** | **服务管理与 7 态状态机** | ✅ **已完成** | 实现 `service_manager.sh` (7态状态转换模型)；重构 `rc.d/mihomo`；清理 configd actions 屏蔽码；API/View 接入实时状态展示。 |
| **Phase 5** | **安全加固** | ✅ **已完成** | 强制 API 127.0.0.1:9090；实现 CSPRNG 32 字节 Secret 管理与脱敏 (`secret_manager.sh`)；实现配置原子更新 (`atomic_config_updater.sh`)；消除 `awk` 文本盲改 XML，引入 `setup_firewall.php`。 |
| **Phase 6** | **Fail-Open 故障旁路机制** | ✅ **已完成** | 实现 `watchdog.sh` 巡检守护与 `do_failopen` 旁路引擎；9 大故障场景自动切回 DIRECT 直连，确保家庭主路由零断网。 |
| **Phase 7** | **TUN 模式与 PF 规则隔离** | ✅ **已完成** | 完善 `setup_firewall.php`：所有规则收敛于独立 `anchor "mihomo"`，实现 `apply_rules` 与 `flush_rules` 快速装卸，放行 TUN、RFC1918 直连并本地保护 API。 |
| **Phase 8** | **Unbound DNS 深度集成与无损回退** | ✅ **已完成** | 完善 `setup_unbound.php`：支持 `install`, `uninstall`, `bypass`, `restore` 四态管理；Mihomo 故障/停止时 100% 无损切回原生上游 DNS，彻底消除 DNS 死锁。 |
| **Phase 9** | **订阅管理与隐私保护** | ✅ **已完成** | 重构 `sub.sh`：彻底剔除 `subconverters.com` 等第三方公网接口；支持原生 YAML 直接拉取与自建私有转换；强制标准 HTTPS 证书校验；集成 `atomic_config_updater.sh`。 |
| **Phase 10**| **综合测试套件** | ✅ **已完成** | 建立 `tests/` 目录并完成 7 大自动化测试脚本，全量执行通过率 100%。 |
| **Phase 11~14**| **发布、VM仿真、实机与长期维护** | ⏳ 规划中 | 待后续阶段执行。 |

---

## 自动化测试与验证指标 (100% PASS)

1. `tests/test_syntax.sh`：**PASS**（全量 Shell、XML、PHP 静态检查）
2. `tests/test_failopen_logic.sh`：**PASS**（Fail-Open 故障旁路直连回滚）
3. `tests/test_atomic_config.sh`：**PASS**（配置原子替换与语法预检回退）
4. `tests/test_secret_manager.sh`：**PASS**（CSPRNG 密钥生成与掩码脱敏）
5. `tests/test_pf_rules.sh`：**PASS**（PF anchor 规则隔离与快速装卸）
6. `tests/test_unbound_integration.sh`：**PASS**（Unbound DNS 联动与故障恢复）
7. `tests/test_subscription_privacy.sh`：**PASS**（零公网第三方转换、强制标准 TLS 校验）
8. `scripts/build.sh && scripts/verify-package.sh`：**PASS**（全量 33 个文件 SHA256 校验 100% 通过，包大小 23,070,073 bytes）
