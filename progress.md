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

---

## 2026-10-18 · v1.0.6：VM 实测三项修复 + 9090 面板密钥 UI（用户报障闭环）

**用户报障**（VM 192.168.30.159，OPNsense 26.7 live ISO）：① 订阅保存报「订阅设置已保存，但写入 sub/env 失败: <UUID>」；② Rules/Status/Logs 三页 Page not found（横幅为 live media 预期提示，非缺陷）；③ 9090 面板要密钥但界面无法查看/修改。

根因与修复：
1. **26.7 configd API 语义**：`Backend::configdRun($event, $detach, ...)` 第二参是 detach，插件按旧签名传参数数组 → detach=true → configd 走异步 execute 只回 job UUID（即报错里的 UUID）。带参数必须走 `configdpRun($event, $params[])`（shlex 安全引号）。SubscriptionController 3 处已改。
2. **configd 动作格式**：`%s` 占位符只能出现在 `parameters:` 模板行；command 行里的 `%s` 会原样传给脚本占住 argv（字面 `%s` + 追加参数 = 参数错位，exit 64 → Execute error）。修了 sub-env-write / setup-cron / config-atomic-update / log 四个动作（log 改为 `command:tail` + `parameters:-n %s ...` 前置模板）。
3. **页面路由**：OPNsense `/ui/{module}/{controller}` 按控制器文件名解析，IndexController 上的 rulesAction/statusAction/logsAction 永远不可达。新增 RulesController/StatusController/LogsController 页面控制器（Firewall 模块同模式），三页实测 200。
4. **9090 面板密钥 UI**：General 页新增「Dashboard API Secret」卡片——掩码展示 / 查看明文 / 一键生成（新密钥仅完整显示一次）/ 自定义设置（4~128 位，白名单字符集 `A-Za-z0-9._~@#%^+=:;,!?*-`，与 sed 替换、YAML 双引号、env 单引号三种落地语境兼容）；secret_manager.sh 新增 `set`（b64 传参+白名单校验）并抽出 apply_secret_files（secret.key/config.yaml/订阅模板/env 四处同步，行缺失自动补写）；改密钥后自动 `mihomo reload`（SIGHUP 热加载，实测新密钥 200/旧密钥 401）。
5. **加固**：subscription_env_writer 与 secret_manager 解码 b64 前剥离全部空白（CLI base64(1) 76 列折行兼容）。

**防回归**：新增 `tests/test_webgui_pages.sh`（每菜单页必须有同名页面控制器 + 禁止 configdRun 数组第二参 + 动作 command 行禁止 %s + 密钥 API 闭环）；test_secret_manager.sh 扩到 5 组（b64 设置/三处同步/拒绝矩阵/env 行补写）。**套件 13/13 PASS**。

**VM 实测全过**：订阅 set API 返回 ok（URL 掩码不变、同值回写 diff 零变化、http URL 正确拒绝）；四页 200；secret reveal/set/regenerate 全通；9090 面板 Bearer 认证 200；cron.d 6h 订阅 + 1min watchdog 在位；secret.key == config.yaml == template == env 四处一致（原密钥 d046… 保留，可在界面查看）。

**最终包 `output/os-mihomo-1.0.6.pkg` SHA256=a5e994f5ddc05d5c872bf4cd934199e1203968e5e708d8d811fd2bc168d38682**（旧包移入 output/archive/）。

---

## 2026-10-18 · v1.0.7：双模型审计修复（Gemini+DeepSeek 并行编码 + 交叉审计 + 主控验收 + VM 回归）

**审计驱动**：v1.0.6 经 Gemini(5 条)+DeepSeek(14 条) 双模型审计、逐条独立复核（16/19 成立，0 高危）后，19 条发现全量修复。工作流拓扑：Gemini 领 PHP/面板包（6 文件）、DeepSeek 领密钥脚本包（2 文件）并行编码（文件集不相交），全量 13 测试门禁（首次全过），交叉审计互审对方包（DeepSeek 给 PHP 包 4 条已回炉、Gemini 审脚本包 0 条），主控再亲审 diff + VM php -l + 部署回归。

**5 条 medium**：① 密钥操作复用 sub_lib 同一把锁（mkdir+pid+陈旧清理逐字节同语义，等 120s 超时报忙）；② getGeneral/setGeneral 收敛 general 子树（getModelNodes 官方覆盖点 + setAction 过滤版，实测 subscription/customRules 不再泄露）；③ apply_secret_files 原子写+逐文件写后校验失败即非零（0500 目录实测复现过修复前后）；④ secret-set 后订阅缓存存在则 rules-recompose 重合成（authentication 行随密钥轮换）+ 显式 reload 并校验 SIGHUP 输出；⑤ （①的同族）。**低危 9 条**：is_string 输入校验、LogsController configdpRun、ACL 补 ui/mihomo(/)与 service/subscription patterns、reveal POST 化、masked 短密钥不泄露前缀、sed 提取正则吃注释、无换行文件补换行、b64 argv 注释如实化、[failopen] 注释、构建元数据版本号。

**VM 回归全过**：getGeneral 顶层仅 general 键；控制器路径轮换 → "Sent SIGHUP" 校验 → 9090 新 200/旧 401 → 恢复 200；reveal GET 拒、数组拒；四页 200；订阅保存 ok；锁真机验证（nohup 活持有者→等 11s+；杀持有者→5s 轮询清陈旧锁→完成）；四处密钥一致；服务 RUNNING/PROXY；面板 200。

**最终包 `output/os-mihomo-1.0.7.pkg` SHA256=6a682808bb67460267d0e8cb020f5c532fbc3ca3791137c56adabdcecf2c23d6**（1.0.6 移入 archive）。

---

## 2026-10-19 · v1.0.8：9090 地址/端口面板可配 + 零硬编码（三轮方案审计 + 双模型编码 + 主控验收）

**需求演化**：用户最初要 LAN 网段白名单（PF 方案 v1/v2/v2.1，两轮审计 5 条 HIGH 后废弃）→ 用户裁定改为"绑定地址面板直配" → 追加"端口也可配 + 硬编码清零"。三轮方案审计（54 条发现、5 HIGH 全部吸收），方向本身三轮零挑战。

**功能**：面板新增「API 绑定地址」（api_bind，默认 127.0.0.1，可填接口 IP/0.0.0.0）与「API 端口」（api_port，默认 9090，IntegerField 1024-65535）；lan_api 死字段移除。渲染 = 密钥轮换同款 sed 双文件 + SIGHUP（实测重建 listener 含绑定地址、0.0.0.0 为 tcp46 双栈）。**配置驱动探测**：22→33 处 9090 字面量清零（sub_lib mihomo_lib_api_addr 单一解析口径，0.0.0.0→127.0.0.1 归一化），消费点含 transport_manager 门禁/安装门禁/watchdog/status/运维脚本。

**安全契约**：三层端口 deny-list（<1024、1053/7890/7891、动态 WebGUI/SSH 实际端口——防 root mihomo 重启竞速抢占 22/80/443 致双失联）；secret 有效值门禁（以 config.yaml 实际值为准而非 secret.key）；绑定非本机地址拒绝（防 API 整体起不来）；**控制面/数据面解耦**（API 探测失败不再杀进程——改为 reconcile+告警，fail-open 判据改为数据面 socks/DNS，防误杀连带 DNS 失效）；断言精确匹配+负向（旧监听必须消失）+有界轮询+回滚。

**编码**：双模型并行（DeepSeek shell/基础设施 13 文件含 §2.6 解耦；Gemini PHP/面板/打包 8 文件含升级迁移）；门禁 14/14 首轮全绿；交叉审计 DeepSeek 给 PHP 包 11 条（修复步骤因 13.8M token 上下文卡死，主控接管亲审 diff 全部吸收——含 config.xml 迁移临时文件 0640 权限修复）；Gemini 审 shell 包通过。

**VM 回归全过**：升级迁移（0.0.0.0:9090 自动导入模型）；三态切换（0.0.0.0→LAN IP→改端口 19090→还原）监听/认证/模板/panel-state/模型五处一致；deny-list（1053/443 拒）；127.0.0.1 拒连；watchdog 62s 无误杀；四页 200；**打包缺陷修复**：__pycache__ 混入包（staging 加 exclude + 主控清理）。

**最终包 `output/os-mihomo-1.0.8.pkg` SHA256=9ddc4db250497ff46049de57b86c229e4e2af9025f9b3b58ef560105c5a3b8ab**。VM 现态：0.0.0.0:9090（用户原状态保持），五处一致，服务 RUNNING。
