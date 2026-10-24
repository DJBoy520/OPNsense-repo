{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

{{ partial('OPNsense/Mihomo/styles') }}

<div class="mihomo-page">
    <!-- 1. 服务概览 -->
    <div class="mihomo-card">
        <div class="mihomo-card-head">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-dashboard"></i> {{ lang._('服务概览') }}</span>
            </h2>
            <button class="btn btn-default btn-xs" id="btn_refresh_status" type="button">
                <i class="fa fa-refresh"></i> {{ lang._('立即刷新') }}
            </button>
        </div>
        <div class="mihomo-card-body">
            <div class="mihomo-stat-grid">
                <!-- 1. 服务状态 -->
                <div class="mihomo-stat">
                    <div class="mihomo-stat-label">{{ lang._('服务状态') }}</div>
                    <div class="mihomo-stat-value" style="margin-bottom: 8px;">
                        <span id="stat_state_desc" class="label label-default" style="font-size: 13px; padding: 3px 8px;">
                            <i class="fa fa-spinner fa-spin"></i> {{ lang._('检查中') }}
                        </span>
                    </div>
                    <div style="font-size: 12px; color: #666;">
                        <span>TUN: <span id="stat_tun" class="label label-default" style="font-size: 11px; padding: 2px 6px;">-</span></span>
                        <span style="margin-left: 8px;">API: <span id="stat_api" class="label label-default" style="font-size: 11px; padding: 2px 6px;">-</span></span>
                    </div>
                </div>

                <!-- 2. 接入方式 -->
                <div class="mihomo-stat">
                    <div class="mihomo-stat-label">{{ lang._('接入方式') }}</div>
                    <div class="mihomo-stat-value" style="margin-bottom: 8px;">
                        <span id="stat_mode" class="label label-default" style="font-size: 13px; padding: 3px 8px;">-</span>
                    </div>
                    <div style="font-size: 12px; color: #666;">
                        <span id="stat_transport" class="mihomo-mono">-</span>
                    </div>
                </div>

                <!-- 3. 内核模式 -->
                <div class="mihomo-stat" id="stat_core_mode">
                    <div class="mihomo-stat-label">{{ lang._('内核模式') }}</div>
                    <div class="mihomo-mode-row" style="margin-bottom: 6px;">
                        <select id="core_mode_select" class="form-control input-sm" style="display: inline-block; width: auto; height: 28px; padding: 2px 8px; font-size: 12px;">
                            <option value="rule">{{ lang._('规则分流 (rule)') }}</option>
                            <option value="global">{{ lang._('全局代理 (global)') }}</option>
                            <option value="direct">{{ lang._('直连 (direct)') }}</option>
                        </select>
                        <button class="btn btn-primary btn-xs" id="btn_core_mode_apply" type="button" style="padding: 4px 10px;">
                            <i class="fa fa-check"></i> {{ lang._('应用') }}
                        </button>
                    </div>
                    <div style="font-size: 12px; display: flex; align-items: center; justify-content: space-between;">
                        <span id="core_mode_config" class="text-muted">{{ lang._('配置默认：-') }}</span>
                        <span id="core_mode_msg" style="font-size: 11px;"></span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- 2. 运行指标 -->
    <div class="mihomo-card">
        <div class="mihomo-card-head">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-line-chart"></i> {{ lang._('运行指标') }}</span>
            </h2>
        </div>
        <div class="mihomo-card-body">
            <div class="mihomo-metric-grid">
                <div class="mihomo-metric">
                    <div class="mihomo-stat-label">{{ lang._('运行时长') }}</div>
                    <div class="mihomo-stat-value mihomo-mono" id="stat_uptime" style="font-size: 14px;">-</div>
                </div>
                <div class="mihomo-metric">
                    <div class="mihomo-stat-label">{{ lang._('内存占用') }}</div>
                    <div class="mihomo-stat-value mihomo-mono" id="stat_memory" style="font-size: 14px;">-</div>
                </div>
                <div class="mihomo-metric">
                    <div class="mihomo-stat-label">{{ lang._('进程 ID') }}</div>
                    <div class="mihomo-stat-value mihomo-mono" id="stat_pid" style="font-size: 14px;">-</div>
                </div>
                <div class="mihomo-metric">
                    <div class="mihomo-stat-label">{{ lang._('插件 / 内核版本') }}</div>
                    <div class="mihomo-stat-value mihomo-mono" style="font-size: 12px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                        <span id="stat_plugin_version">-</span> / <span id="stat_mihomo_version">-</span>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- 3. 诊断详情（默认折叠） -->
    <div class="mihomo-card">
        <div class="mihomo-card-head" style="cursor: pointer;" data-toggle="collapse" data-target="#diagnostic_details">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-wrench"></i> {{ lang._('诊断详情') }}</span>
                <small class="text-muted" style="font-size: 12px; font-weight: normal; margin-left: 8px;">
                    <i class="fa fa-chevron-down"></i> {{ lang._('点击展开/折叠') }}
                </small>
            </h2>
        </div>
        <div id="diagnostic_details" class="collapse">
            <div class="mihomo-card-body">
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
            </div>
        </div>
    </div>
</div>

<script>
$(function () {
    var coreModeNames = {
        'rule': '规则分流',
        'global': '全局代理',
        'direct': '直连'
    };

    function loadRuntimeMode() {
        ajaxGet('/api/mihomo/status/getMode', {}, function (data) {
            var $msg = $('#core_mode_msg');
            if (data && data.reachable && data.mode) {
                $('#core_mode_select').val(data.mode);
                if ($msg.hasClass('text-danger')) {
                    $msg.removeClass('text-danger text-warning').text('');
                }
            } else {
                var note = (data && data.note) ? data.note : 'API 不可达';
                $msg.removeClass('text-success text-warning').addClass('text-danger').text(note);
            }
        });
    }

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
                    $mode.addClass('label-info').text('接入：透明代理');
                } else {
                    $mode.addClass('label-primary').text('接入：仅代理');
                }
            } else {
                $mode.addClass('label-default').text('接入：直连');
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

            var cfgMode = data.core_mode || 'rule';
            var cfgDesc = coreModeNames[cfgMode] || cfgMode;
            $('#core_mode_config').text('配置默认：' + cfgDesc);

            // 当服务未运行时，禁用内核模式切换
            if (state !== 'RUNNING') {
                $('#core_mode_select').prop('disabled', true);
                $('#btn_core_mode_apply').prop('disabled', true);
                $('#core_mode_msg').removeClass('text-success text-warning').addClass('text-muted').text('服务未运行');
            } else {
                $('#core_mode_select').prop('disabled', false);
                $('#btn_core_mode_apply').prop('disabled', false);
            }
        });
    }

    $('#btn_core_mode_apply').click(function () {
        var selectedMode = $('#core_mode_select').val();
        var $btn = $(this);
        var $msg = $('#core_mode_msg');

        $btn.prop('disabled', true);
        $msg.removeClass('text-danger text-success').addClass('text-muted').text('切换中...');

        ajaxCall('/api/mihomo/status/setMode', { mode: selectedMode }, function (res) {
            $btn.prop('disabled', false);
            if (res && res.status === 'ok') {
                $msg.removeClass('text-danger text-muted').addClass('text-success').text(res.message || '切换成功');
                setTimeout(function () {
                    refreshStatus();
                    loadRuntimeMode();
                }, 500);
            } else {
                var err = (res && res.message) ? res.message : '切换失败';
                $msg.removeClass('text-success text-muted').addClass('text-danger').text(err);
            }
        });
    });

    $('#btn_refresh_status').click(function () {
        refreshStatus();
        loadRuntimeMode();
    });

    refreshStatus();
    loadRuntimeMode();
    setInterval(refreshStatus, 4000);
});
</script>
