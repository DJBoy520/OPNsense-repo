# DESIGN: 9090 External-Controller LAN 放开（lan_api 字段转正）— v2.1

状态：v2.1（v2 + SIGHUP 实测裁决；待快速复审后实施）
日期：2026-10-18
v2 → v2.1：**实施 Step 0 已完成**——VM 实测（mihomo v1.19.30，pid 不变）：`external-controller` 绑定行 sed 后 SIGHUP，监听地址即时切换（`tcp46 *:9090` → `tcp4 127.0.0.1:9090` → `tcp46 *:9090`）。裁决：**SIGHUP 会重建 API listener（DeepSeek 读源码结论正确，Gemini 错误）**；api_bind_manager 直接用 reload，删除 restart 回退分支。**附带实测发现：0.0.0.0 绑定实际是 tcp46 双栈监听（IPv6 同样在听）**——PF 规则因此**不加 inet 限定**（v4/v6 都要管住），撤销 v2 吸收的"规则加 inet"条目。
关联：目标版本 1.0.8。

## 1. 背景与目标（不变）

- 用户已在 192.168.30.161:28002 自部署 metacubexd，直连路由器 9090 API；内置 zashboard 不做 LAN 化改造（注意：见 §8——绑定放开后 `/ui/` 静态页随 listener 自然可达，属附带事实而非功能目标）。
- 诉求：9090 只对配置网段（默认用户所在 LAN）放开，其余不可达；关闭回 127.0.0.1。
- 最高约束：绝不引入断网 / WebGUI 失联 / DNS 失效；**不得出现"绑定已放开而 PF 限制缺失"的持续状态（fail-closed 原则）**。

## 2. 现状事实（v1 盘点 + 审计修正）

1. `mihomo.general.lan_api` 死字段转正；新增 `lan_api_cidr`。
2. `external-controller: 127.0.0.1:9090` 在 config.yaml / sub/template_config.yaml / sample 第 8 行；**compose 对该行零改写、模板直通**（sub_lib 全文无 external-controller 处理）。
3. **[审计修正]** `mihomo_firewall()` 的 `registerAnchor` 只向主规则集注入 `anchor "名字"` 引用声明，**不承载、不渲染、不持久化任何规则内容**；重启后内核 anchor 为空。既有 transport 的正确做法是 transport_manager.sh 渲染规则文件后 `pfctl -a mihomo-transport -f` 显式装载——mihomo-api 必须照此模式自建 renderer+loader。
4. **[审计修正]** filter reload 会清空 anchor 内容（非空 named anchor 在同一规则集中保留与否不可依赖），装载必须独立于 filter reload 的幂等动作。
5. transport anchor policy 红线（禁 block）只约束 mihomo-transport；mihomo-api 是独立 anchor，其唯一 block 精确到 `(self):9090`，renderer 静态断言规则形状（见 §5）。
6. mihomo external-controller 无 IP 白名单（v1.19.30）；CORS 不是访问控制。
7. **[实测裁决]** SIGHUP 会重建 API listener（含绑定地址）：VM 实测两次往返切换均即时生效（见文首 v2.1 说明），api_bind_manager 直接用 reload；运行期仍保留 sockstat 断言防未来版本行为漂移。
8. `transport_render.php` 已有 lan-net / lan-ip 推导与 canonical_cidr（filter_var + ip2long），直接复用。
9. panel-state.env 既有通道（GeneralController 写、sub_lib/service_manager 读）。

## 3. 方案设计

### 3.1 模型层（真源）

- `lan_api` 转正（BooleanField，默认 0），help 文案如实（含"/ui/ 静态页将随 listener 可达"的说明）。
- 新增 `general.lan_api_cidr`：TextField。
  - 模型 `<Mask>` 锚定正则（`\A(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}/(3[0-2]|[12]\d|[1-9])\z`）：拒绝空格/换行/前导零/非法掩码。
  - 控制器二次校验：filter_var(FILTER_VALIDATE_IP) + prefix 1..32 + **显式拒绝 0.0.0.0/0** + host-bits 归一化（复用 canonical_cidr 思路）。
  - **非法值拒绝保存并报错（不静默回落）**；空值 = 未配置，开启开关时必填校验拦截。
  - 默认值：表单渲染时用 transport_render.php lan-net 推导预填实际 LAN 网段（多 LAN 取全部并列渲染为多个 table 成员）；推导失败才允许手填。
- 单 CIDR 字段（v2 不做多网段列表；多 LAN 场景由推导预填多个成员进 table，模型仍存一个主网段——如需多网段留待后续迭代，避免本版膨胀）。

### 3.2 运行态执行器：`api_bind_manager.sh`（新脚本，独立 configd 动作 `api-bind-apply`）

参数：`<lan:0|1> <cidr>`（控制器传入；脚本内对两参数再校验一遍，不信任调用方）。

职责与内部顺序（**启用方向：先立盾，后开门**）：

1. 获取订阅锁 `/var/run/mihomo-sub.lock`（**GUI 场景短等待：5s×3 次，拿不到输出 busy 错误 exit 非 0**——与 secret_manager 的 120s 策略区分，面板请求不能挂 2 分钟）。
2. 校验 config.yaml 与 template_config.yaml 存在（缺失则明确报错跳过该文件，**绝不创建只有绑定行的残缺 YAML**）。
3. **PF 先行**：渲染 `/var/db/os-mihomo/pf-api.active.conf`（lan=1 时含下述规则，lan=0 时为空文件），`pfctl -a mihomo-api -f <file>`，随后 `pfctl -a mihomo-api -sr` 断言规则数与期望一致（lan=1 必须 >0）。
   ```
   table <mihomo_api_clients> const { 127.0.0.1 ::1 __MIHOMO_API_CIDR__ }
   pass in quick on lo0 proto tcp to 127.0.0.1 port 9090 keep state
   pass in quick on __MIHOMO_LAN_IF__ proto tcp from <mihomo_api_clients> to (__MIHOMO_LAN_IF__) port 9090 keep state
   block in quick proto tcp to (__MIHOMO_LAN_IF__) port 9090
   ```
   - **接口限定**（审计修正）：pass 限定 lo0 与 LAN 接口、目标限定接口自身 IP；block 限定目标为 LAN 口自身地址 9090——WAN 上伪造源 IP 的包不匹配任何 pass、命中 block；不触碰转发流量（无转发语义，仅 to 本机地址）。
   - **[实测修正] 规则不加 inet**：0.0.0.0 绑定实测为 tcp46 双栈监听（IPv6 同样在听），规则必须同时覆盖 v4/v6；table 含 ::1（本机 v6 回环放行），v6 其他源命中 block——fail-closed。
   - **block 范围有意的 policy 例外**：本 anchor 会在 head 覆盖管理员对 (LAN-IP):9090 的自定义放行——这是插件对自身管理面的保护语义，renderer 静态断言全文只允许上述形状（pass 在前、唯一 block 精确匹配），防止未来把 block 扩大；README 红线表述同步更新。
   - **PF states**：CIDR 收窄或关闭时 `pfctl -a mihomo-api -F states`，防长寿 WebSocket 绕过新策略。
4. **绑定行渲染**：sed config.yaml 与 template 的 `^external-controller:` 行（lan=1 → `0.0.0.0:9090`；lan=0 → `127.0.0.1:9090`），写后 `grep -qF` 校验；行缺失先补末行换行再追加；目标文件缺失跳过并报错。
5. **生效**：mihomo 在运行（有 pid）才执行——`service_manager.sh reload` 后 **sockstat 断言**实际监听地址 == 期望（0.0.0.0 或 127.0.0.1 的 9090），不一致则 restart 一次再断言；仍不一致 → 回滚（绑定写回原值 + reload + PF 恢复）并 exit 1。**mihomo 未运行时只改文件与 PF，不 reload/不 start**（避免把用户停掉的服务拉起——审计修正）；下次 do_start 自然生效。
6. 幂等：重复执行结果一致；成功输出 `OK: api bind <lan|local> cidr=<cidr>`（失败摘要同时写 stdout——configd script_output 只回传 stdout，stderr 前端拿不到——审计修正）。
7. 锁释放 trap 兜底（同 secret_manager 模式）。

### 3.3 生命周期装载点（fail-closed 核心，审计 HIGH 修正）

mihomo-api anchor 内容**不会**经 registerAnchor/filter reload 持久化，以下四个点必须显式装载：

| 装载点 | 动作 |
| --- | --- |
| **do_start**（service_manager.sh，mihomo 启动**之前**） | 读模型 lan_api（经 panel-state.env 通道，见 §3.5）：lan=1 → 渲染+装载 anchor 并断言规则数>0；**装载失败或规则数为 0 → 强制把绑定写回 127.0.0.1 再启动 mihomo（fail-closed）**，日志告警 |
| **+POST_INSTALL**（健康门禁之后） | 幂等 reconcile：按模型渲染绑定行与 anchor（快照恢复可能带回旧绑定，此处收敛），失败仅告警不阻断安装 |
| **watchdog 巡检**（新增低频检查项） | `lan_api=1 且 pfctl -a mihomo-api -sr 规则数为 0` → 自动重装载；连续失败 → 告警并 fail-closed 回绑 127.0.0.1 |
| **面板开关**（api-bind-apply，§3.2） | 全时序见 §3.4 |

### 3.4 控制器层（GeneralController::setGeneralAction）

- **保存前拦截**（审计修正：必须在 setAction() 落盘之前）：POST 中 lan_api=1 时，先经 configd 校验 secret 已配置（用 secret-masked != NOT_CONFIGURED 判定，避免 configd 错误输出被误判），未配置 → 直接返回失败并引导到密钥面板，**不落盘**。
- **幂等 reconcile**：不再只做 old/new 变化分支——每次保存都读模型（lan_api/cidr/lan_user/enabled）执行 api-bind-apply（脚本幂等，无变化时为空操作）；同时保留 transport 等既有变化分支。审计修正：快照恢复/HA 回写/历史勾选都能在任意一次保存后收敛。
- CIDR 非法 → 拒绝保存（见 §3.1）；脚本 busy/失败 → 透传 stdout 摘要给前端。
- reload/start 语义不与 api-bind 叠加：控制器现有 enabled 分支不变；api-bind-apply 自身遵守"未运行不拉起"。
- getGeneral 的 general 子树带出 lan_api/lan_api_cidr（现有 getModelNodes 已覆盖）。

### 3.5 真源与通道

- 模型 = 唯一真源；`panel-state.env` 扩展两个键：`MIHOMO_LAN_API`、`MIHOMO_LAN_API_CIDR`（GeneralController writePanelState 同款原子写），供 do_start / watchdog 在**不读 config.xml 的后端环境**里拿到模型状态（与 MIHOMO_LAN_EXPOSE 同通道同风格）。
- 文件渲染以"模型 → panel-state → 脚本渲染"单向流，杜绝双向漂移。

### 3.6 用户使用路径（验收故事，不变）

面板勾选 lan_api（CIDR 自动预填 LAN 网段）→ Save & Apply → metacubexd（192.168.30.161:28002）添加 `http://<路由器IP>:9090` + Show Secret 的密钥。关闭开关即回收。

## 4. 改动文件清单（修订）

| 文件 | 改动 |
| --- | --- |
| models/OPNsense/Mihomo/Mihomo.xml | lan_api help；新增 lan_api_cidr（含 Mask） |
| controllers/.../forms/general.xml | cidr 输入框 + 预填 + 文案 |
| Api/GeneralController.php | 保存前 secret 拦截；幂等 reconcile；panel-state 扩展；错误透传 |
| scripts/OPNsense/Mihomo/api_bind_manager.sh | **新增**（渲染绑定+PF+sockstat 断言+回滚） |
| scripts/OPNsense/Mihomo/service_manager.sh | do_start 增加装载点（fail-closed）；其余不动 |
| scripts/OPNsense/Mihomo/watchdog.sh | 新增 anchor 空规则巡检项 |
| packaging/freebsd/+POST_INSTALL | 健康门禁后幂等 reconcile；chmod 列表加新脚本 |
| packaging/freebsd/+PRE_DEINSTALL | `pfctl -a mihomo-api -F all` |
| service/conf/actions.d/actions_mihomo.conf | [api-bind-apply]（%s 只在 parameters 行） |
| etc/inc/plugins.inc.d/mihomo.inc | mihomo_firewall() 注册 `mihomo-api` anchor **引用**（仅引用声明，内容由 §3.2 装载） |
| scripts/OPNsense/Mihomo/transport_render.php | 复用/暴露 lan-ip 与 canonical_cidr |
| tests/* | CIDR 校验矩阵、api_bind_manager 两态/失败路径/幂等、anchor 形状断言、test_webgui_pages 守卫 |
| 文档 | README 红线表述、index.volt 与 sub.sh 隧道提示、status 页 API 暴露状态展示 |

## 5. 风险与红线（修订）

- mihomo-api anchor 的 block **有意**覆盖管理员对 (LAN-IP):9090 的自定义放行（head+quick），范围精确且 renderer 断言形状；转发流量（route-to/ NAT）零触碰。
- fail-closed 双保险：绑定持久化（config.yaml）+ PF 空窗由"启动前装载 + 失败回绑 127.0.0.1 + watchdog 兜底"三层封堵；仍保留的最坏窗口 ≤ 单次启动时长，且方向是**收回**而非放开。
- secret 前置 + 64-hex + 面板轮换；Bearer 明文经 HTTP 属 LAN 信任边界内的已知接受风险（文档明示；如需更高保障另评估 external-controller-tls）。
- `/ui/` 静态页随 listener 对 CIDR 内可达（无需 secret）——如实写入验收与面板文案。
- 双栈事实：0.0.0.0 绑定实测为 tcp46（v4+v6 都在听），anchor 规则不加 inet、同时覆盖两栈；v6 管理面默认被 block（fail-closed），如需 v6 访问走 SSH 隧道。
- 不动 mihomo-transport anchor、不碰主规则集、不改 sub_lib 合成算法（external-controller 仍走模板直通）。

## 6. 实施第一步与验收清单（修订）

**Step 0（已完成）**：VM 实测 SIGHUP——**会重建 listener 并切换绑定地址**（v2.1 文首记录），api_bind_manager 固化为 reload 分支 + sockstat 断言，无 restart 回退。

验收（在 v1 清单上增补）：
1. 开启：filter reload → anchor 规则数>0 → 绑定 0.0.0.0 → SIGHUP → sockstat 断言 → 网段内 curl 带 secret 200 / 不带 401。
2. WAN 伪造源不可达：pfctl -a mihomo-api -s rules 核对接口限定；如可造源路由则实测。
3. 重启后（装盘 VM）：9090 绑定与 anchor 自动恢复且匹配模型；关闭开关状态同样恢复。
4. 停服（enabled=0）状态下开关：只改文件与 PF，服务不被拉起。
5. CIDR 收窄：`pfctl -a mihomo-api -F states` 执行，旧 WebSocket 断开。
6. 失败注入：手动清空 anchor 文件 + 重启 → fail-closed 回绑 127.0.0.1 → watchdog 告警。
7. 订阅 Update Now 与开关并发：锁保护下无相互覆盖。
8. 关闭开关：绑回 127.0.0.1 → filter reload 移除引用 → flush anchor 与 states → 网段内 curl 不可达。
9. 卸载：anchor 被 flush，无残留规则。
