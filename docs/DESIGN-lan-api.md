# DESIGN: external-controller 绑定地址可配置（v3 简化方案）

状态：v3（产品方向修订：**绑定地址由用户配置**，放弃 v1/v2 的 PF/CIDR 白名单方案；待 Gemini + DeepSeek 审计）
日期：2026-10-18
决策记录：PF CIDR 方案（v1/v2/v2.1）经两轮审计 34+20 条发现、5 条 HIGH，复杂度与家庭单 LAN 场景收益严重不成比例，用户裁定改为"绑定地址面板直配"。本版为完整重写，PF 相关设计全部废弃。
关联：目标版本 1.0.8。

## 1. 目标与产品语义

- 面板提供"**API 绑定地址**"配置项（`general.api_bind`），默认 `127.0.0.1`；用户可改为本机任一接口 IP（如 `192.168.30.159`）或 `0.0.0.0`。
- 渲染语义 = mihomo 原生 socket 绑定：`127.0.0.1` 仅本机；接口 IP 仅发往该地址的连接（LAN 侧可达、WAN IP/其他接口 IP 连不上）；`0.0.0.0` 全接口（实测 tcp46 双栈）。
- **不做任何 PF/防火墙改动**；无 SSH 隧道强依赖（LAN IP 绑定下 metacubexd 直接指向 `http://<LAN IP>:9090`）。
- secret 仍是唯一认证层；**绑定非 127.0.0.1 时强制要求 secret 已配置**（保存前置拦截）。
- 最高约束不变：不引入断网 / WebGUI 失联 / DNS 失效；失败方向天然 fail-closed（渲染失败 = 保持旧值 = 最多"没放开"）。

## 2. 行为定义

### 2.1 值域与校验

- 值域：合法 IPv4 单地址（`127.0.0.1`、`0.0.0.0`、本机已分配的接口 IP）。**不接受 CIDR、不接受主机名**（mihomo bind 需要字面 IP）。
- 三层校验：
  1. 模型 `<Mask>`：`/\A(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\z/`（**带分隔符**——v2.1 复审实测无分隔符 preg_match 直接报错；拒绝换行/空格/CIDR）。
  2. 控制器（GeneralController 覆盖的 setAction 内，**两条路由都覆盖**）：filter_var(FILTER_VALIDATE_IP) 复核。
  3. 渲染脚本：本机地址核验——`0.0.0.0`/`127.0.0.1` 直接放行；其余必须出现在 `ifconfig -a` 的 inet 列表（**防 bind 非本机地址导致 API listener 整个起不来**），核验失败报错不渲染。
- 非法值拒绝保存并报错（不静默回落）。

### 2.2 渲染与生效

- 沿用密钥轮换同款 sed 模式：`config.yaml` 与 `sub/template_config.yaml` 的 `^external-controller:` 行改为 `<bind>:9090`；**写后 `grep -qF "external-controller: <bind>:9090"` 校验，失败指名报错 exit 1**；行缺失先补末行换行再追加；目标文件缺失跳过并报错。
- 生效：mihomo 运行中才 `service_manager.sh reload`（SIGHUP 已实测重建 listener 含绑定地址），随后 **sockstat 断言**：`sockstat -l -p 9090`（**不带 -4**——tcp46 实测教训），匹配 `*:9090` 或 `<bind>:9090` 或 `127.0.0.1:9090`；断言失败 → **自动回滚为旧绑定值 + reload + 再次断言**，仍失败 exit 1 并把摘要写 stdout（configd script_output 只回传 stdout）。
- mihomo 未运行：只改文件，不 reload、不 start（避免拉起停用的服务）。
- 订阅更新：模板已改，compose 直通继承。
- 锁：写两文件必须持有 `/var/run/mihomo-sub.lock`（复用 secret_manager 同款锁协议；GUI 场景 5s×3 短等待，busy 输出明确错误）。

### 2.3 探测地址适配（唯一成规模的改动，审计重点核对覆盖完整性）

绑定改掉后，`127.0.0.1:9090` 的硬编码探测会失败。统一适配规则：**从 config.yaml 读绑定地址（awk 取 `^external-controller:` 的 host 段），`0.0.0.0` 归一化为 `127.0.0.1` 探测**。已知硬编码点（实施时以此清单为准并全局 grep 复核）：

| 文件 | 位置 | 现状 | 适配 |
| --- | --- | --- | --- |
| service_manager.sh | check_api_ready / do_healthcheck | `curl http://127.0.0.1:9090`、`sockstat -4 -l -p 9090` | 探测 URL 用绑定地址（归一化）；sockstat 去 -4 并匹配实际地址 |
| watchdog.sh | API 探测（fail-open 判据之一） | 同上 | 同上 |
| system_status.py | API_PORT=9090 探测 | 同上 | 同上 |
| +POST_INSTALL | port_up 健康门禁 | sockstat grep `(127.0.0.1|\*|0.0.0.0):$1` | grep 模式加入 `<bind>`（从 config.yaml 读） |

### 2.4 生命周期

| 事件 | 行为 |
| --- | --- |
| 面板保存 | 幂等渲染（每次保存都执行，不只变化时——防快照/HA 回写漂移） |
| do_start | reconcile：config.yaml 绑定 != panel-state 记录 → 按模型重渲染（mihomo 启动前，失败仅告警不阻断启动——方向 fail-closed） |
| +POST_INSTALL | 快照恢复后、`service mihomo restart` **前**：reconcile 一次（此时未运行，只改文件）；port_up 门禁用适配后的探测 |
| 订阅更新 | 模板继承，无需处理 |
| 卸载 | 无 PF 遗留；随配置删除，无清理动作 |
| LAN IP 变化（DHCP） | 文档明示绑定 LAN IP 应使用静态地址；IP 变化后 mihomo 启动 bind 失败 → API down（方向 fail-closed），面板改新地址保存即恢复 |

### 2.5 面板与文案（如实原则）

- forms/general.xml：移除 lan_api 复选框；新增"API 绑定地址"输入框（placeholder 预填推导的 LAN IP；help 写明三档语义：127.0.0.1 仅本机 / 接口 IP 该网段可用 / 0.0.0.0 全接口含 WAN，以及"非 127.0.0.1 时 `/ui/` 静态页免密可达、API 走 Bearer 明文 HTTP"的如实警示）。
- Mihomo.xml：**移除死字段 lan_api**（历史配置中的残留值被 OPNsense 模型忽略，无迁移动作）；新增 api_bind。
- getGeneral：general 子树返回 api_bind；前端 Show Secret / metacubexd 指引文案与绑定地址联动显示（"当前地址 http://<bind>:9090，bind=127.0.0.1 时提示 SSH 隧道用法"）。

## 3. 安全事实（如实声明，不做隐瞒）

- 非 127.0.0.1 绑定后：API（需 secret）与 `/ui/` 静态资源（**免密**）对可达来源开放。
- Bearer 密钥走明文 HTTP：LAN 信任边界内的已知接受风险（同网段嗅探/ARP 欺骗可截获）；如需更高保障属独立特性（TLS/反代），本版不做。
- `0.0.0.0` 含 WAN 接口：外部屏障是 OPNsense 默认 WAN 拒绝；**推荐单 LAN 用户绑定 LAN IP 而非 0.0.0.0**（文案引导）。
- 密钥轮换能力（v1.0.7）与绑定改动共用同一把锁，互不覆盖。

## 4. 改动文件清单

| 文件 | 改动 |
| --- | --- |
| models/OPNsense/Mihomo/Mihomo.xml | 移除 lan_api；新增 api_bind（含 Mask） |
| controllers/.../forms/general.xml | api_bind 输入框 + 如实文案；移除旧复选框 |
| Api/GeneralController.php | setAction 内前置校验（IP 合法 + 非 127 需 secret）+ 保存后 api-bind-apply；getGeneral 附带 api_bind |
| scripts/OPNsense/Mihomo/api_bind_manager.sh | **新增**（锁 → 本机地址核验 → 双文件 sed+校验 → reload+sockstat 断言+回滚 → 探测归一化辅助） |
| scripts/OPNsense/Mihomo/service_manager.sh | healthcheck/check_api_ready 探测地址适配 |
| scripts/OPNsense/Mihomo/watchdog.sh | API 探测地址适配 |
| scripts/OPNsense/Mihomo/system_status.py | API 探测地址适配 |
| packaging/freebsd/+POST_INSTALL | port_up 适配 + restart 前 reconcile + chmod 列表 |
| service/conf/actions.d/actions_mihomo.conf | [api-bind-apply]（%s 只在 parameters 行） |
| tests/* | 校验矩阵、渲染/回滚/断言、探测归一化、守卫 |

## 5. 验收清单

1. 默认 127.0.0.1：行为与现状完全一致（本地 curl 200、LAN 拒绝）。
2. 改 LAN IP：LAN curl 带 secret 200 / 不带 401；`127.0.0.1:9090` 不再监听；healthcheck/watchdog/status 全绿（探测适配生效）；SSH 隧道改指 LAN IP 可用。
3. 改 0.0.0.0：`tcp46 *:9090`；WAN 侧依赖默认拒绝（无需任何 mihomo anchor）。
4. secret 未配置时改绑 → 拒绝并引导。
5. 绑定非本机地址（如 10.9.9.9）→ 渲染脚本本机核验拒绝。
6. reload 断言失败注入 → 自动回滚旧绑定。
7. 订阅 Update Now、重启（装盘 VM）、pkg 升级后绑定保持且探测全绿。
8. secret 轮换与绑定改动并发：锁保护下无相互覆盖。
9. 停服（enabled=0）状态下改绑定：只改文件，服务不被拉起，下次启动生效。
10. 面板文案与实际行为一致（/ui/ 免密、明文 Bearer 声明）。

## 6. 与被否方案的对照（决策存档）

- v1/v2/v2.1（PF CIDR）：两轮审计 5 条 HIGH（anchor 不物化、重启裸奔、WAN 伪造、引用缺失、block 脱靶）+ 生命周期状态机复杂度失控 → 废弃。
- 本方案把访问控制从"防火墙规则生命周期"降维为"socket bind 语义"，失败方向天然 fail-closed；精确多网段白名单如有真实需求，属未来独立特性。
