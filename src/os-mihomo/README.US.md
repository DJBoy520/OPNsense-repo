<div align="center">
  <a href="README.md">中文</a> |
  <a href="README.US.md">English</a>
</div>

# Mihomo for OPNsense

![OPNsense](https://img.shields.io/badge/OPNsense-orange)
![Mihomo](https://img.shields.io/badge/Mihomo-MetaCubeX-purple)

Mihomo, formerly Clash Meta, is a high-performance open source proxy core compatible with Clash configuration files. It provides rule-based routing, DNS handling, load balancing, and transparent proxy support.

This project packages Mihomo as an OPNsense plugin so it can run on OPNsense and provide transparent proxy functionality through the OPNsense WebGUI.

Tested on:

- OPNsense 26.1.9

![](images/mihomo.us.png)

## Binary Supply Chain

The project uses **only the official static binary from [MetaCubeX](https://github.com/MetaCubeX/mihomo)**, downloaded directly from the official GitHub release:

```text
https://github.com/MetaCubeX/mihomo/releases/download/v{VERSION}/mihomo-freebsd-amd64-v{VERSION}.gz
```

The version is pinned in `mihomo-version.env`. Every download is verified against a **SHA256 strong hash** — any mismatch aborts the build immediately. There are no third-party binary forks or unofficial mirrors in the supply chain.

## Security Features

- **Official supply chain**: MetaCubeX releases only, SHA256-verified, zero third-party binary dependencies.
- **API local protection**: Clash API is force-bound to `127.0.0.1:9090` — no direct external access is possible.
- **CSPRNG Secret masking**: A 32-byte cryptographically secure random API secret is generated automatically; the WebGUI always displays it masked.
- **Fail-Open bypass**: The watchdog monitors 9 fault scenarios and automatically falls back to DIRECT routing — the primary router never goes offline due to a proxy failure.
- **PF Anchor isolation**: All firewall rules are confined to a dedicated `anchor "mihomo"`, allowing one-shot load/unload without polluting the main ruleset.
- **Zero-leak subscriptions**: The subscription manager eliminates all third-party public converters. It supports native YAML pull or self-hosted private converters, with mandatory standard HTTPS certificate validation.
- **Unbound DNS lossless fallback**: When Mihomo fails or stops, DNS automatically reverts to the native upstream resolver, eliminating DNS deadlock entirely.

## Notes

1. Only x86_64 / amd64 is currently supported.
2. After installation, no interface or firewall rule needs to be added manually. Edit the node information in the default configuration and use it directly.
3. After debugging is complete, set the log level to `error` to avoid excessive long-term logs.
4. The Clash API is force-bound to `127.0.0.1:9090` and is accessible via the built-in WebGUI panel. **Do not expose port 9090 to the WAN.**
5. Do not change the TUN interface name `tun_mihomo` in `config.yaml`, otherwise the installer-generated firewall rules may stop matching.
6. This package configures Unbound to forward queries to port 1053 (the mihomo DNS listener) and applies a `geosite:cn` filter to the Fake-IP mechanism: domestic domains resolve to their real IPs, while foreign domains use Fake-IPs.

## Install

Upload the package to OPNsense and run:

```sh
pkg add -f os-mihomo.pkg
```

After installation, refresh the OPNsense WebGUI and go to:

```text
VPN > Mihomo
```

## Uninstall

```sh
pkg delete os-mihomo
```

## Subscription Updates

Automatic subscription updates can be scheduled with Cron:

```text
System > Settings > Cron
```

Add a scheduled task and select:

```text
Renew mihomo Subscription
```

## Build

Build on Ubuntu/Debian or FreeBSD/OPNsense. Run:

```sh
bash scripts/build.sh
```

Output file:

```text
output/os-mihomo-*.pkg
```

Verify package integrity:

```sh
bash scripts/verify-package.sh
```

Inspect package metadata:

```sh
pkg info -F output/os-mihomo-*.pkg
```

## Common Commands

Service control:

```sh
service mihomo start
service mihomo stop
service mihomo status
service mihomo restart
service mihomo rcvar
```

View logs:

```sh
tail -f /var/log/mihomo.log
```

Check listening ports:

```sh
sockstat -4 -l | egrep ':53|:1053|:7891|:9090'
```

Check the TUN interface:

```sh
ifconfig tun_mihomo
```

Check runtime firewall rules:

```sh
pfctl -sr | grep -E 'mihomo'
```

Inspect PF anchor details:

```sh
pfctl -a mihomo -sr
```

Check watchdog / Fail-Open status:

```sh
/usr/local/opnsense/scripts/mihomo/watchdog.sh status
```

## Troubleshooting

| Symptom | Steps |
|---|---|
| Proxy not connecting | `service mihomo status`; check `/var/log/mihomo.log` |
| DNS resolution failing | `dig @127.0.0.1 -p 1053 example.com`; verify Unbound forwarding state |
| API unreachable | API only listens on `127.0.0.1:9090`; access via the WebGUI panel, not directly from WAN |
| Subscription update fails | Verify target URL certificate validity; check `/var/log/mihomo-sub.log` |
| PF rules not applied | `pfctl -a mihomo -sr`; verify the anchor is loaded |
| Fail-Open triggered | Watchdog has switched to direct routing; see `/var/log/mihomo-watchdog.log` for the trigger reason |

## Credits

[MetaCubeX](https://github.com/MetaCubeX/mihomo)

## Disclaimer

> [!CAUTION]
> This is an unofficial plugin and is not supported by the OPNsense team. Use it at your own risk.
