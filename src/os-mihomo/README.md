<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Mihomo for OPNsense

![OPNsense](https://img.shields.io/badge/OPNsense-red)
![Mihomo](https://img.shields.io/badge/Mihomo-MetaCubeX-purple)

Mihomo（原 Clash Meta）是一款高性能、功能丰富的开源代理核心，兼容 Clash 配置格式，并在此基础上扩展了更多协议和高级功能，支持多种代理协议，提供灵活的规则分流、DNS 管理、负载均衡和透明代理功能。凭借其优秀的性能和广泛的兼容性，Mihomo 已成为构建现代网络代理和流量管理解决方案的重要工具之一。

本项目是一个用于 OPNsense 的 Mihomo 插件，用于在 OPNsense 上运行 Mihomo 并实现透明代理功能。

在以下环境测试通过：

- OPNsense 26.1.9

![](images/mihomo.png)

## 项目程序

项目直接使用 [MetaCubeX](https://github.com/MetaCubeX/mihomo) 官方发布的静态二进制文件，通过锁定版本号与 **SHA256 强哈希校验**确保供应链完整性。构建脚本会从以下官方地址下载：

```text
https://github.com/MetaCubeX/mihomo/releases/download/v{VERSION}/mihomo-freebsd-amd64-v{VERSION}.gz
```

版本号由 `mihomo-version.env` 锁定，每次下载后强制比对 SHA256 校验和，任何篡改均会导致构建中止。

## 安全特性

- **官方供应链**：仅使用 MetaCubeX 官方 Release，SHA256 强校验，零第三方二进制依赖。
- **API 本地保护**：Clash API 强制绑定 `127.0.0.1:9090`，拒绝所有外网直接访问。
- **CSPRNG Secret 掩码**：32 字节密码学安全随机数作为 API Secret，WebGUI 展示时自动脱敏。
- **Fail-Open 故障旁路**：watchdog 巡检 9 大故障场景，自动切回 DIRECT 直连，主路由永不因代理故障断网。
- **PF Anchor 隔离**：所有防火墙规则收敛于独立 `anchor "mihomo"`，一键装卸，不污染主规则集。
- **本地零外泄订阅**：订阅管理彻底剔除第三方公网转换器，支持原生 YAML 直拉或自建私有转换，强制标准 HTTPS 证书校验。
- **Unbound DNS 无损回退**：Mihomo 故障或停止时，自动恢复原生上游 DNS，杜绝 DNS 死锁。

## 注意事项

1. 当前仅支持 x86_64 / amd64 平台。
2. 安装完成，无需添加接口、防火墙规则，只需修改节点信息即可使用。
3. 安装调试完成后，将日志层级调整为 `error`，避免长期运行产生过多日志。
4. Clash API 强制绑定本地 `127.0.0.1:9090`，可通过 WebGUI 内嵌面板访问，**请勿将 9090 端口暴露至外网**。
5. 修改配置不要改动 `config.yaml` 文件中 TUN 接口名称（`tun_mihomo`），否则会影响安装程序生成的默认防火墙规则。
6. 本安装包通过在 Unbound 添加一个指向 1053 端口（mihomo 监听端口）的转发来处理本地 DNS 查询，同时在 Fake-IP 增加 `geosite:cn` 过滤，实现国内域名返回真实 IP，国外域名使用 Fake-IP。

## 安装命令

将安装包上传到 OPNsense 后执行：
```sh
pkg add -f os-mihomo.pkg
```
安装完成后刷新 OPNsense WebGUI，进入：
```text
VPN > Mihomo
```

## 卸载命令
```sh
pkg delete os-mihomo
```

## 订阅更新
自动更新订阅可通过 Cron 完成：
```text
转到 系统 > 设置 > 任务
```
添加定时任务，在命令项，找到以下命令并添加：
```sh
Renew mihomo Subscription
```

## 编译 pkg
在 Ubuntu/Debian 或 FreeBSD/OPNsense 主机上均可构建。运行：

```sh
bash scripts/build.sh
```
输出文件：

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
查看日志：
```sh
tail -f /var/log/mihomo.log
```
检查监听端口：
```sh
sockstat -4 -l | egrep ':53|:1053|:7891|:9090'
```
检查 TUN 接口：
```sh
ifconfig tun_mihomo
```
检查防火墙运行规则：
```sh
pfctl -sr | grep -E 'mihomo'
```
查看 PF Anchor 详情：
```sh
pfctl -a mihomo -sr
```
手动触发 Fail-Open 旁路状态：
```sh
/usr/local/opnsense/scripts/mihomo/watchdog.sh status
```

## 故障排查（Troubleshooting）

| 现象 | 排查步骤 |
|---|---|
| 代理无法连接 | `service mihomo status`；检查 `/var/log/mihomo.log` |
| DNS 解析异常 | `dig @127.0.0.1 -p 1053 example.com`；检查 Unbound 转发状态 |
| API 无法访问 | API 仅监听 `127.0.0.1:9090`，通过 WebGUI 面板访问，勿从外网直连 |
| 订阅更新失败 | 检查目标 URL 证书有效性；查看 `/var/log/mihomo-sub.log` |
| PF 规则未生效 | `pfctl -a mihomo -sr`；检查 anchor 是否已加载 |
| Fail-Open 触发 | watchdog 已切回直连，查看 `/var/log/mihomo-watchdog.log` 了解触发原因 |

## 致谢
[MetaCubeX](https://github.com/MetaCubeX/mihomo)

## 免责声明
> [!CAUTION]
> 非官方插件，无 OPNsense 团队支持。使用者自行承担一切后果。
