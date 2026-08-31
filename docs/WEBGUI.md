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
* **`Services`**
  * **`Mihomo`**
    * **`General`** (`/ui/mihomo/index`)：启用/禁用插件主服务，配置运行日志级别，通过按钮触发 Start / Stop / Restart / Reload 服务控制。
    * **`Status`** (`/ui/mihomo/status`)：展示 Plugin Version、Mihomo Version、Commit、SHA256、服务 7 态运行状态、TUN 接口状态、API 状态、PID 与内存占用。
    * **`Logs`** (`/ui/mihomo/logs`)：实时分页查看 Mihomo 核心日志，支持 Debug/Info/Warning/Error 级别过滤与敏感信息自动脱敏。

### 3.2 安全设计细节
1. **统一经由 configd**：
   - 所有的服务动作（如 `start`, `stop`, `restart`, `reload`）均通过 `(new Backend())->configdRun("mihomo <action>")` 触发，严禁在 PHP 中直接执行命令。
2. **敏感信息脱敏过滤器**：
   - `LogsController.php` 实现了模式匹配脱敏器，对日志行中的 `secret: ...`、`token: ...`、`password: ...` 以及 UUID 等凭证进行动态掩码替换为 `[REDACTED_SECRET]`。
