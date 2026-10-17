<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Mihomo for OPNsense

![OPNsense](https://img.shields.io/badge/OPNsense-red)
![Mihomo](https://img.shields.io/badge/Mihomo-MetaCubeX-purple)

Mihomo（原 Clash Meta）是一款高性能、功能丰富的开源代理核心，兼容 Clash 配置格式，并在此基础上扩展了更多协议和高级功能，支持多种代理协议，提供灵活的规则分流、DNS 管理、负载均衡和透明代理功能。凭借其优秀的性能和广泛的兼容性，Mihomo 已成为构建现代网络代理和流量管理解决方案的重要工具之一。

本项目是一个用于 OPNsense 的 Mihomo 插件。v3 起以 **socks 核心模式**交付：mihomo 只负责代理与 DNS 解析，透明代理传输由路由器既有的 hev-socks5-tunnel + PF route-to 体系承担，插件不再修改 `/conf/config.xml`、PF 主规则集与 Unbound。

## 目标平台与验证状态

- 目标平台：OPNsense 26.7 / FreeBSD 15.1，amd64。
- 构建与静态回归在开发环境（Linux）完成，入口为 `tests/test_*.sh`；本仓库**不声明**已在某个具体 OPNsense 版本上完成端到端验收。
- 部署后请按本文「常用命令」与「故障排查」在目标机自检；生产上线前请在维护窗口内验证。

![](images/mihomo.png)

## 架构（socks 核心模式）

- **mihomo 仅作 socks 核心**：socks5 `127.0.0.1:7891`、DNS `127.0.0.1:1053`、RESTful API `127.0.0.1:9090`。所有监听均绑定本地回环。
- **传输层外置**：透明代理由 hev-socks5-tunnel（`tun0`）+ PF `route-to` 承担，属于路由器既有体系；插件安装/卸载不新增或删除 PF 规则，也不触碰 Unbound。
- **TUN 在 FreeBSD 不可用**：mihomo 的 sing-tun 后端没有 FreeBSD 实现，开启 TUN 后实测报 `configure tun interface: invalid argument`（见 [MetaCubeX/mihomo issue #1157](https://github.com/MetaCubeX/mihomo/issues/1157)）。因此 `config.yaml` 固定 `tun.enable: false`，**请勿开启**。
- **Fail-Open**：watchdog 以进程、API(9090)、DNS(1053)、socks(7891) 监听为健康判据；异常时停掉 mihomo 并切回直连，DNS 由上游 fallback 自然回退，主路由不会因代理故障断网。

## 项目程序

项目直接使用 [MetaCubeX](https://github.com/MetaCubeX/mihomo) 官方发布的静态二进制文件，通过锁定版本号与 **SHA256 双重校验**（压缩包 + 解包后二进制）确保供应链完整性。构建脚本从以下官方地址下载：

```text
https://github.com/MetaCubeX/mihomo/releases/download/v1.19.30/mihomo-freebsd-amd64-compatible-v1.19.30.gz
```

版本 URL、文件名与两个 SHA256 均由 `src/os-mihomo/build/mihomo-version.env` 锁定。

仪表盘面板（zashboard）同样按版本锁定并随包内置，构建时下载并校验 SHA256 后解压到 `/usr/local/etc/mihomo/ui`，运行期不下载任何前端资源。

## 安全特性

- **官方供应链**：仅使用 MetaCubeX 官方 Release（当前锁定 v1.19.30 compatible），压缩包与解包二进制均做 SHA256 强校验，零第三方二进制依赖。
- **内置面板零运行期下载**：zashboard 随包内置（`external-ui` 指向本地目录，不配置 `external-ui-url`），避免运行期拉取任意前端资源。
- **Geo 数据手动更新**：默认 `geo-auto-update: false`，需要时经 Clash API 或手动替换 Geo 文件更新，避免后台自动下载。
- **Secret 不进 argv**：CSPRNG 生成 32 字节 API Secret，订阅注入与轮换通过环境变量（`ENVIRON`）和 0600 临时 sed 脚本完成，不出现在进程参数中；WebGUI 展示自动脱敏。
- **订阅原子更新**：订阅 URL 仅允许 `https://`，日志掩码到 host 级；合成配置先由 `mihomo -t` 校验，通过后才备份并原子替换 `config.yaml`，坏订阅永远不会覆盖生产配置。
- **API 本地保护**：Clash API 强制绑定 `127.0.0.1:9090`，面板经 SSH 隧道访问，勿暴露到外网。
- **Fail-Open 故障旁路**：watchdog 巡检进程/API/DNS/socks 监听，异常时切回直连。
- **零系统侵入**：安装与卸载不修改 `/conf/config.xml`、Unbound 与 PF 主规则集，避免与既有网络体系互相污染。

## 注意事项

1. 当前仅支持 x86_64 / amd64 平台。
2. 插件不创建 TUN、不下发 PF 规则；透明代理依赖路由器既有的 hev-socks5-tunnel + PF route-to 体系。
3. 安装调试完成后，将日志层级调整为 `error`，避免长期运行产生过多日志。
4. Clash API 仅监听 `127.0.0.1:9090`，面板通过 SSH 隧道访问，**请勿将 9090 端口暴露至外网**。
5. 必须保持 `tun.enable: false`：FreeBSD 无 sing-tun 实现，开启会导致启动失败（issue #1157）。
6. 插件不修改 Unbound。DNS 查询需要由上游（Unbound 或 AdGuardHome 等）转发到 `127.0.0.1:1053`，由运维按既有 DNS 架构配置。

## 安装命令

将安装包上传到 OPNsense 后执行：
```sh
pkg add -f os-mihomo.pkg
```
安装钩子会初始化 secret、启动服务，并在 30 秒内检查 `1053/7891/9090` 三个监听；若未就绪，详情写入 `/root/os-mihomo-install-warning.log`（不会自动改动 DNS/PF）。

安装完成后刷新 OPNsense WebGUI，进入：
```text
Services（服务） > Mihomo
```

## 面板访问（SSH 隧道）

面板已随包内置（zashboard）。在管理终端建立隧道：

```sh
ssh -L 9090:127.0.0.1:9090 root@<OPNsense_LAN_IP>
```

保持 SSH 会话，然后在浏览器打开：

```text
http://127.0.0.1:9090/ui
```

登录所需 Secret 可在插件界面查看（也可执行 `configctl mihomo secret-get`）。

## 卸载命令
```sh
pkg delete os-mihomo
```
卸载时用户配置目录会移动到 `/root/os-mihomo-removed-<时间戳>`，保留订阅、secret 与自定义配置。

## 订阅更新
自动更新订阅可通过 Cron 完成：
```text
转到 系统 > 设置 > 任务
```
添加定时任务，在命令项，找到以下命令并添加：
```sh
Renew mihomo Subscription
```

也可以手动执行：
```sh
configctl mihomo sub-update
tail -f /var/log/mihomo_sub.log
```

## 编译 pkg
在 Ubuntu/Debian 或 FreeBSD/OPNsense 主机上均可构建。运行：

```sh
bash scripts/build.sh
```

构建会校验 mihomo 二进制与 zashboard 的 SHA256，并把面板解压到包的 `usr/local/etc/mihomo/ui`。输出文件：

```text
output/os-mihomo-*.pkg
```
验证包完整性：
```sh
bash scripts/verify-package.sh
```
检查包元数据：
```sh
pkg info -F output/os-mihomo-*.pkg
```

## 常用命令

服务控制：
```sh
service mihomo start
service mihomo stop
service mihomo status
service mihomo restart
service mihomo rcvar
```

configd 动作：
```sh
configctl mihomo status
configctl mihomo system-status
configctl mihomo watchdog
configctl mihomo failopen "manual test"
configctl mihomo sub-update
```

查看日志：
```sh
tail -f /var/log/mihomo.log
tail -f /var/log/mihomo_sub.log
tail -f /var/log/mihomo_watchdog.log
```

检查监听端口：
```sh
sockstat -4 -l | egrep ':1053|:7891|:9090'
```

检查 socks 监听：
```sh
sockstat -4 -l -p 7891
```

检查 DNS 解析：
```sh
dig @127.0.0.1 -p 1053 example.com
```

检查 API（需替换 Secret）：
```sh
curl -s -H "Authorization: Bearer <secret>" http://127.0.0.1:9090/version
```

检查传输层（既有体系，不属本插件管理）：
```sh
ifconfig tun0
pfctl -sr | grep route-to
```

## 故障排查（Troubleshooting）

| 现象 | 排查步骤 |
|---|---|
| 代理无法连接 | `service mihomo status`；`tail -f /var/log/mihomo.log`；`sockstat -4 -l -p 7891` |
| DNS 解析异常 | `dig @127.0.0.1 -p 1053 example.com`；确认上游（Unbound/AGH）已转发到 `127.0.0.1:1053`；插件不修改 Unbound |
| API / 面板无法访问 | API 仅监听 `127.0.0.1:9090`，使用 SSH 隧道访问 `http://127.0.0.1:9090/ui`，勿从外网直连 |
| 订阅更新失败 | 检查目标 URL 是否为 `https://` 且证书有效；`tail -f /var/log/mihomo_sub.log`；校验失败时生产配置保持不变 |
| socks 监听缺失 | `sockstat -4 -l -p 7891`；`service mihomo restart`；查看 `/var/log/mihomo.log` |
| 透明代理不通 | 检查 hev-socks5-tunnel 的 `tun0` 与 PF `route-to` 规则（既有传输层）；本插件不创建 TUN、不下发 PF 规则 |
| 开启 TUN 后启动失败 | FreeBSD 无 sing-tun 实现（[issue #1157](https://github.com/MetaCubeX/mihomo/issues/1157)），保持 `tun.enable: false` |
| Fail-Open 触发 | 查看 `/var/log/mihomo_watchdog.log` 了解触发原因；`configctl mihomo status` 确认已切回直连 |

## 致谢
[MetaCubeX](https://github.com/MetaCubeX/mihomo)

## 免责声明
> [!CAUTION]
> 非官方插件，无 OPNsense 团队支持。使用者自行承担一切后果。
