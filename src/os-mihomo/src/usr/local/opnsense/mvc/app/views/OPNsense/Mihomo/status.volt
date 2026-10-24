{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

{{ partial('OPNsense/Mihomo/styles') }}

<div class="mihomo-page">
    <!-- 顶部 8 个 KPI 卡片 -->
    <div class="row" style="margin-bottom: 15px;">
        <!-- 1. 服务状态 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('服务状态') }}</div>
                <div class="mihomo-kpi-value" style="font-size: 14px;">
                    <span id="stat_state_desc" class="label label-default" style="font-size: 12px; padding: 3px 6px;">
                        <i class="fa fa-spinner fa-spin"></i> {{ lang._('检查中') }}
                    </span>
                    <span id="stat_mode" class="label label-default" style="font-size: 12px; padding: 3px 6px; margin-left: 4px;">-</span>
                </div>
            </div>
        </div>

        <!-- 2. 传输层 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('传输层') }}</div>
                <div class="mihomo-kpi-value mihomo-mono" id="stat_transport" style="font-size: 13px;">-</div>
            </div>
        </div>

        <!-- 3. TUN 接口 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('TUN 接口') }}</div>
                <div class="mihomo-kpi-value">
                    <span id="stat_tun" class="label label-default" style="font-size: 12px; padding: 3px 6px;">-</span>
                </div>
            </div>
        </div>

        <!-- 4. 外部控制 API -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('外部控制 API') }}</div>
                <div class="mihomo-kpi-value">
                    <span id="stat_api" class="label label-default" style="font-size: 12px; padding: 3px 6px;">-</span>
                </div>
            </div>
        </div>

        <!-- 5. 运行时长 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('运行时长') }}</div>
                <div class="mihomo-kpi-value mihomo-mono" id="stat_uptime" style="font-size: 13px;">-</div>
            </div>
        </div>

        <!-- 6. 内存占用 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('内存占用') }}</div>
                <div class="mihomo-kpi-value mihomo-mono" id="stat_memory" style="font-size: 13px;">-</div>
            </div>
        </div>

        <!-- 7. 进程 PID -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('进程 ID') }}</div>
                <div class="mihomo-kpi-value mihomo-mono" id="stat_pid" style="font-size: 13px;">-</div>
            </div>
        </div>

        <!-- 8. 插件/内核版本 -->
        <div class="col-xs-12 col-sm-6 col-md-3">
            <div class="mihomo-kpi">
                <div class="mihomo-kpi-label">{{ lang._('插件 / 内核版本') }}</div>
                <div class="mihomo-kpi-value mihomo-mono" style="font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                    <span id="stat_plugin_version">-</span> / <span id="stat_mihomo_version">-</span>
                </div>
            </div>
        </div>
    </div>

    <!-- 运行状态明细卡片 -->
    <div class="content-box" style="padding-bottom: 1.5em;">
        <div class="col-xs-12">
            <h2 class="mihomo-card-title">{{ lang._('运行状态') }}</h2>
            <p class="text-muted">{{ lang._('Mihomo 核心生命周期、传输层模式、TUN 接口、API 服务与系统指标实时概览。') }}</p>
            <hr/>
        </div>

        <div class="col-xs-12">
            <div class="table-responsive">
                <table class="table table-striped table-bordered table-condensed">
                    <tbody>
                        <tr>
                            <th style="width: 25%;">{{ lang._('Git 提交') }}</th>
                            <td class="mihomo-mono" id="stat_commit">-</td>
                        </tr>
                        <tr>
                            <th>{{ lang._('最近状态消息') }}</th>
                            <td id="stat_message">-</td>
                        </tr>
                        <tr>
                            <th>{{ lang._('最近状态变更') }}</th>
                            <td class="mihomo-mono" id="stat_last_change">-</td>
                        </tr>
                        <tr>
                            <th>{{ lang._('原始状态输出') }}</th>
                            <td><pre id="stat_raw" class="mihomo-mono" style="max-height: 140px; overflow-y: auto; background: transparent; border: 0; padding: 0; margin: 0;">-</pre></td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <button class="btn btn-default" id="btn_refresh_status" type="button">
                <i class="fa fa-refresh"></i> {{ lang._('立即刷新') }}
            </button>
        </div>
    </div>
</div>

<script>
$(function () {
    function refreshStatus() {
        ajaxCall('/api/mihomo/status/getMihomoStatus', {}, function (data) {
            $('#stat_plugin_version').text(data.plugin_version || '-');
            $('#stat_mihomo_version').text(data.mihomo_version || '-');
            $('#stat_commit').text(data.commit || '-');
            $('#stat_pid').text(data.pid ? data.pid : '-');
            $('#stat_memory').text(data.memory || '-');
            $('#stat_uptime').text(data.uptime || '-');
            $('#stat_message').text(data.message || '-');
            $('#stat_last_change').text(data.last_change || '-');
            $('#stat_raw').text(data.raw_status || '-');

            var $mode = $('#stat_mode');
            $mode.removeClass('label-default label-primary label-info');
            var state = (data.state || '').toUpperCase();
            if (state === 'RUNNING') {
                if (data.transport_mode === 'transparent') {
                    $mode.addClass('label-info').text('模式：透明代理');
                } else {
                    $mode.addClass('label-primary').text('模式：代理');
                }
            } else {
                $mode.addClass('label-default').text('模式：直连');
            }

            var $stateDesc = $('#stat_state_desc');
            $stateDesc.removeClass('label-default label-success label-warning label-danger label-info');
            if (state === 'RUNNING') {
                $stateDesc.addClass('label-success').html('<i class="fa fa-check-circle"></i> 运行中');
            } else if (state === 'STARTING') {
                $stateDesc.addClass('label-info').html('<i class="fa fa-spinner fa-spin"></i> 启动中');
            } else if (state === 'STOPPING') {
                $stateDesc.addClass('label-warning').html('<i class="fa fa-spinner fa-spin"></i> 停止中');
            } else if (state === 'DEGRADED') {
                $stateDesc.addClass('label-warning').html('<i class="fa fa-exclamation-circle"></i> 降级');
            } else if (state === 'FAILED') {
                $stateDesc.addClass('label-danger').html('<i class="fa fa-times-circle"></i> 故障');
            } else if (state === 'DISABLED') {
                $stateDesc.addClass('label-default').html('<i class="fa fa-ban"></i> 已禁用');
            } else {
                $stateDesc.addClass('label-default').html('<i class="fa fa-power-off"></i> 已停止');
            }

            var $tun = $('#stat_tun');
            $tun.removeClass('label-default label-success label-danger label-info');
            if (data.tun_status === 'UP') {
                $tun.addClass('label-success').text('正常');
            } else if (data.tun_status === 'DOWN') {
                $tun.addClass('label-danger').text('断开');
            } else {
                $tun.addClass('label-default').text('SOCKS');
            }

            var transportText = '-';
            if (data.transport_mode) {
                var kindText = data.tun_kind ? ' (' + data.tun_kind + ')' : '';
                var modeText = data.transport_mode === 'transparent' ? '透明代理' :
                    (data.transport_mode === 'proxy' ? '代理' : String(data.transport_mode).toUpperCase());
                transportText = modeText + kindText;
            }
            $('#stat_transport').text(transportText);

            var $api = $('#stat_api');
            $api.removeClass('label-default label-success label-danger');
            if (data.api_status === 'UP') {
                $api.addClass('label-success').text('正常');
            } else {
                $api.addClass('label-danger').text('不可用');
            }
        });
    }

    $('#btn_refresh_status').click(refreshStatus);
    refreshStatus();
    setInterval(refreshStatus, 4000);
});
</script>
