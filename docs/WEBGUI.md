# Secure OPNsense Mihomo — WebGUI 原生 MVC 架构文档 (Phase 3)

> 文档编号：WEBGUI-DOC-001  
> 适用版本：os-mihomo 1.0.2+  
> 架构规范：OPNsense 26.7+ Phalcon MVC  

---

## 一、 WebGUI 架构重构总览

在 Phase 3 中，彻底清除了旧版本存在重大安全隐患的 4 个面向过程 PHP 页面（`src/usr/local/www/mihomo*.php`），并全面迁移至 OPNsense 官方推行的标准 **Phalcon MVC**（Model-View-Controller）架构。

### 1.1 架构对比与安全提升

| 维度 | 改造前 (Legacy Procedural PHP) | 改造后 (OPNsense Native MVC) |
| :--- | :--- | :--- |
| **页面架构** | `src/usr/local/www/` 独立单脚本 | `opnsense/mvc/app/` 分层 MVC (Volt/Controller/Model) |
| **访问控制** | 日志接口缺失 `guiconfig.inc` (严重未授权访问漏洞) | 接入 OPNsense 全局 ACL 鉴权框架 (`ACL.xml`) |
| **CSRF 防护** | 局部自建 `$_SESSION` Token，易被破坏 | 原生集成 OPNsense Session / XSRF Token 保护 |
| **系统调用** | 大量 PHP 直接 `exec()` 调用 Shell | 严格使用 `(new Backend())->configdRun()` 间接调用 |
| **敏感脱敏** | 日志接口明文打印 Secret / Token | `LogsController` 自动过滤 Secret / Token / 密码 / UUID |

---

## 二、 核心 MVC 组件清单

```
src/usr/local/opnsense/
├── mvc/app/
│   ├── models/OPNsense/Mihomo/
│   │   ├── Menu/Menu.xml                 # 菜单声明：Services -> Mihomo -> General/Status/Logs
│   │   ├── ACL/ACL.xml                   # ACL 权限声明：UI 路由与 API 端点权限控制
│   │   ├── Mihomo.php                    # Model 业务对象 (继承 OPNsense\Base\BaseModel)
│   │   └── Mihomo.xml                    # 配置字段 Schema (enabled, log_level, lan_api)
│   ├── controllers/OPNsense/Mihomo/
│   │   ├── IndexController.php           # 页面路由控制器 (提供 index, status, logs 页面)
│   │   ├── forms/general.xml             # General 页面表单定义
│   │   └── Api/
│   │       ├── ServiceController.php     # 服务启停 API (start, stop, restart, reload, status)
│   │       ├── GeneralController.php     # 配置读取与保存 API (getGeneral, setGeneral)
│   │       ├── StatusController.php      # 运行与健康状态 API (7态状态机、TUN、PID、内存)
│   │       └── LogsController.php        # 安全日志查询 API (支持级别过滤与脱敏)
│   └── views/OPNsense/Mihomo/
│       ├── index.volt                    # General 页面视图模板 (开关、日志级别、启停按钮组)
│       ├── status.volt                   # Status 页面视图模板 (版本、哈希、7态运行监控卡片)
│       └── logs.volt                     # Logs 页面视图模板 (带级别过滤的实时日志查看器)
└── service/conf/actions.d/
    └── actions_mihomo.conf               # configd 动作注册
```

---

## 三、 Web 界面与功能规格

### 3.1 菜单结构
* **服务**
  * **Mihomo**
    * **常规设置** (`/ui/mihomo/`)：服务控制、运行参数、面板密钥、订阅与策略来源。
    * **分流规则** (`/ui/mihomo/rules`)：自定义规则表格/源码编辑，以及当前生效规则分页查看。
    * **运行状态** (`/ui/mihomo/status`)：KPI 卡片（状态/传输层/TUN/API/运行时长/内存/PID/版本）+ 明细表。
    * **实时日志** (`/ui/mihomo/logs`)：亮色表格实时日志，级别过滤/暂停/清屏/下载/自动滚动。

### 3.2 安全设计细节
1. **统一经由 configd**：
   - 所有的服务动作（如 `start`, `stop`, `restart`, `reload`）均通过 `(new Backend())->configdRun("mihomo <action>")` 触发，严禁在 PHP 中直接执行命令。
2. **敏感信息脱敏过滤器**：
   - `LogsController.php` 实现了模式匹配脱敏器，对日志行中的 `secret: ...`、`token: ...`、`password: ...` 以及 UUID 等凭证进行动态掩码替换为 `[REDACTED_SECRET]`。

---

## 四、 v1.1.0 界面规范

### 4.1 视觉与排版

- 共享样式片段 `views/OPNsense/Mihomo/styles.volt`，四个页面统一引入；只允许 `.mihomo-*` 前缀，不覆盖 OPNsense 全局样式。
- 亮色卡片：白底 + `#e3e3e3` 边框 + 4px 圆角 + 轻阴影；强调色只用 OPNsense 橙 `#d94f00`。
- Status 顶部 8 个 KPI 卡片；General 四张卡片（服务控制 / 运行参数 / 面板与 API / 订阅与策略）；Rules 两张卡片；Logs 工具栏 + 亮色日志表。
- 日志区禁止深色控制台色（`#1e1e1e`、`#2d2d2d`、`#dcdcdc`、`#2e2e2e`）；表头 sticky，时间列弱化，级别用标准 `label-*` 徽章。
- 表头 sticky 必须挂在 `thead th` 上（`tr` 上的 sticky 在 Chrome 不生效）。
- 响应式：`.mihomo-toolbar` 在 <768px 时纵向排列。

### 4.2 中文化

- 四个页面、三个 form、Menu、ACL、模型 OptionValues/ValidationMessage 的可见文案全部为简体中文。
- 技术标识保留英文：`DIRECT`、`REJECT`、`REJECT-DROP`、`DOMAIN`、`GEOSITE`、`RULE-SET`、`no-resolve`、`SOCKS`、`TUN`、`API`、`Mihomo`、`zashboard`。
- 日志正文（mihomo 原始输出）不翻译；级别徽章显示中文（调试/信息/警告/错误/致命），下载时使用 `data-level` 保留原始级别。
- OPNsense 自身的顶栏/菜单语言仍由系统语言设置决定；本插件内容固定中文。

### 4.3 大规则集下的生效规则

- `getEffectiveRules` 先用 `/version` 做安全探测（`-m 3`、`-K` 传 Bearer、secret 不进 argv），随后由 PHP `fopen/fgets` 流式读取 `config.yaml` 的 `rules:` 块。
- 查询参数 `limit`（默认 200，1~1000）、`offset`、`q`（<=200 字符，去控制字符）；返回 `total`/`truncated`/`query`。
- 前端 `#effective_prev`/`#effective_next`/`#effective_page_info` 翻页，`#filter_effective_rules` 350ms 防抖后走服务端搜索；行号为 `offset+idx+1`。
- 实测 357,229 条规则下首屏 200 条、搜索 `google` 793 条、末页 4 条，页面不卡死。
