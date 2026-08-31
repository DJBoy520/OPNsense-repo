# Secure OPNsense Mihomo — 安全设计与加固规范 (Phase 5)

> 文档编号：SEC-HARDEN-001  
> 适用版本：os-mihomo 1.0.2+  
> 核心模块：API 安全 / CSPRNG Secret / 配置原子更新 / 订阅脱敏 / DOM 驱动安全安装  

---

## 一、 四大安全加固维度总览

```
+---------------------------------------------------------------------------------------+
|                                    SECURITY HARDENING                                 |
+---------------------------------------------------------------------------------------+
|  1. API 安全防御        | 强制 external-controller 监听 127.0.0.1:9090；默认防火墙严格阻断   |
|                         | WAN/LAN 访问；API 必须设置 Secret 凭证方可启动。                      |
+-------------------------+-------------------------------------------------------------+
|  2. 敏感凭据全生命周期   | CSPRNG (openssl/urandom) 生成 32 字节高熵 Secret；文件权限 0600；   |
|     脱敏与隔离          | 前端表单与日志脱敏为 ******** 或掩码；配置导出全面脱敏。            |
+-------------------------+-------------------------------------------------------------+
|  3. 配置原子化更新      | 临时文件 (mktemp 0600) -> mihomo -t 语法预检 -> 备份旧配置 ->        |
|     (Atomic Update)     | 原子覆盖 (mv) -> 触发 reload；异常时保留旧配置且零中断。            |
+-------------------------+-------------------------------------------------------------+
|  4. 消除 XML 文本篡改   | 彻底移除 +POST_INSTALL/+PRE_DEINSTALL 中 awk 修改 XML 逻辑；        |
|     (No Awk XML Hack)   | 引入 setup_firewall.php 依托 DOMDocument 及排他锁安全管理配置。     |
+---------------------------------------------------------------------------------------+
```

---

## 二、 API 安全设计与访问控制

1. **本地回环监听强制锁定**：
   - 生产模板与运行时配置强制锁定 `external-controller: 127.0.0.1:9090`，杜绝 `0.0.0.0` 带来的内网/外网未授权管理风险。
2. **防火墙隔离策略**：
   - WAN -> 9090：**DENY**
   - LAN -> 9090：**DENY**（默认）
   - localhost -> 9090：**ALLOW**
   - 未来如需在 WebGUI 启用 LAN API，必须明确绑定指定接口与子网，**永远禁止暴露于 WAN 侧**。

---

## 三、 Secret 凭证管理与全链路脱敏

1. **CSPRNG 生成机制**：
   - 由 `secret_manager.sh` 执行 `openssl rand -hex 32`（或 `/dev/urandom`）生成 256-bit 高熵安全密钥。
   - 存储路径：`/usr/local/etc/mihomo/secret.key` 与 `config.yaml`，权限严格设置为 `0600`。
2. **WebGUI 与日志脱敏**：
   - Web 界面通过 `GeneralController::getGeneralAction` 返回 `secret_masked`（如 `a1b2************************************`），前端禁止回显明文 Secret。
   - 提供「重新生成 Secret (Regenerate)」API，重新生成后自动同步至各组件并安全重载。
   - `LogsController.php` 具备动态凭证脱敏引擎，自动掩码日志中出现的 `secret`, `token`, `password`, `uuid` 字段为 `[REDACTED_SECRET]`。

---

## 四、 配置原子化更新流水线 (Atomic Update Workflow)

核心管理脚本：`src/usr/local/opnsense/scripts/OPNsense/Mihomo/atomic_config_updater.sh`

```
  新配置输入 (YAML)
         │
         ▼
  [ 步骤 1: mktemp 0600 创建独立临时文件 ]
         │
         ▼
  [ 步骤 2: 注入配置并执行 mihomo -t 验证 ] ──(验证失败)──► [ 删除临时文件 / 保持当前实例 / 报错退出 ]
         │
    (验证成功)
         ▼
  [ 步骤 3: 备份当前旧配置为 config.yaml.bak ]
         │
         ▼
  [ 步骤 4: 原子文件替换 (mv -f tmp config.yaml) ]
         │
         ▼
  [ 步骤 5: 触发 Mihomo 热重载 /service_manager.sh reload ]
         │
         ▼
       成功完成
```

---

## 五、 安装与卸载的配置安全性 (DOM 驱动)

1. **废弃 awk 文本篡改**：
   - 旧版本在 `+POST_INSTALL` 与 `+PRE_DEINSTALL` 中使用 `awk` 对 `/conf/config.xml` 进行正则替换，极易造成 XML 标签闭合错误或配置丢失。
2. **引入 `setup_firewall.php`**：
   - 建立面向对象的 `DOMDocument` / `DOMXPath` 安全解析引擎；
   - 在操作 `/conf/config.xml` 前强制获取 `/var/run/os-mihomo-firewall.lock` 文件排他锁；
   - 自动生成带时间戳的完整配置备份（`.bak.os-mihomo-firewall-*`）；
   - 使用原子重命名写入配置，并在卸载时完全清理接口节点与放行规则，实现零残留。
