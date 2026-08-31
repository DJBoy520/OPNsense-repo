{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - System & Service Status') }}</h2>
        <p class="text-muted">{{ lang._('Real-time overview of Mihomo core 7-state lifecycle, mode, TUN interface, API server, and system metrics.') }}</p>
        <hr/>
    </div>

    <div class="col-xs-12">
        <table class="table table-striped table-bordered table-condensed">
            <tbody>
                <tr>
                    <th style="width: 25%;">{{ lang._('Service State') }}</th>
                    <td>
                        <span id="stat_state_desc" class="label label-default" style="font-size: 13px; padding: 4px 8px;">
                            <i class="fa fa-spinner fa-spin"></i> {{ lang._('Loading...') }}
                        </span>
                        <span id="stat_mode" class="label label-default" style="font-size: 13px; padding: 4px 8px; margin-left: 6px;">-</span>
                    </td>
                </tr>
                <tr>
                    <th>{{ lang._('Plugin Version') }}</th>
                    <td id="stat_plugin_version">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Mihomo Core Version') }}</th>
                    <td id="stat_mihomo_version">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Git Commit') }}</th>
                    <td id="stat_commit">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Process PID') }}</th>
                    <td id="stat_pid">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Memory Usage') }}</th>
                    <td id="stat_memory">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Uptime') }}</th>
                    <td id="stat_uptime">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('TUN Interface Status') }}</th>
                    <td>
                        <span id="stat_tun" class="label label-default">-</span>
                    </td>
                </tr>
                <tr>
                    <th>{{ lang._('External Controller API') }}</th>
                    <td>
                        <span id="stat_api" class="label label-default">-</span>
                    </td>
                </tr>
                <tr>
                    <th>{{ lang._('Last State Message') }}</th>
                    <td id="stat_message">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Last State Change') }}</th>
                    <td id="stat_last_change">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Raw Status / Output') }}</th>
                    <td><pre id="stat_raw" style="max-height: 120px; overflow-y: auto; background: transparent; border: 0; padding: 0; margin: 0;">-</pre></td>
                </tr>
            </tbody>
        </table>

        <button class="btn btn-default" id="btn_refresh_status" type="button">
            <i class="fa fa-refresh"></i> {{ lang._('Refresh Now') }}
        </button>
    </div>
</div>

<script>
$(function () {
    function refreshStatus() {
        ajaxCall('/api/mihomo/status/getMihomoStatus', {}, function (data) {
            $('#stat_plugin_version').text(data.plugin_version || '-');
            $('#stat_mihomo_version').text(data.mihomo_version || '-');
            $('#stat_commit').text(data.commit || '-');
            $('#stat_pid').text(data.pid ? data.pid : 'N/A');
            $('#stat_memory').text(data.memory || '-');
            $('#stat_uptime').text(data.uptime || '-');
            $('#stat_message').text(data.message || '-');
            $('#stat_last_change').text(data.last_change || '-');
            $('#stat_raw').text(data.raw_status || '-');

            var $mode = $('#stat_mode');
            $mode.removeClass('label-default label-primary label-info');
            if (data.mode === 'PROXY') {
                $mode.addClass('label-primary').text('MODE: PROXY');
            } else {
                $mode.addClass('label-default').text('MODE: DIRECT');
            }

            var $stateDesc = $('#stat_state_desc');
            $stateDesc.removeClass('label-default label-success label-warning label-danger label-info');
            var state = (data.state || '').toUpperCase();
            if (state === 'RUNNING') {
                $stateDesc.addClass('label-success').html('<i class="fa fa-check-circle"></i> RUNNING');
            } else if (state === 'STARTING') {
                $stateDesc.addClass('label-info').html('<i class="fa fa-spinner fa-spin"></i> STARTING');
            } else if (state === 'STOPPING') {
                $stateDesc.addClass('label-warning').html('<i class="fa fa-spinner fa-spin"></i> STOPPING');
            } else if (state === 'DEGRADED') {
                $stateDesc.addClass('label-warning').html('<i class="fa fa-exclamation-circle"></i> DEGRADED');
            } else if (state === 'FAILED') {
                $stateDesc.addClass('label-danger').html('<i class="fa fa-times-circle"></i> FAILED');
            } else if (state === 'DISABLED') {
                $stateDesc.addClass('label-default').html('<i class="fa fa-ban"></i> DISABLED');
            } else {
                $stateDesc.addClass('label-default').html('<i class="fa fa-power-off"></i> STOPPED');
            }

            var $tun = $('#stat_tun');
            $tun.removeClass('label-default label-success label-danger');
            if (data.tun_status === 'UP') {
                $tun.addClass('label-success').text('UP');
            } else {
                $tun.addClass('label-danger').text('DOWN');
            }

            var $api = $('#stat_api');
            $api.removeClass('label-default label-success label-danger');
            if (data.api_status === 'UP') {
                $api.addClass('label-success').text('UP');
            } else {
                $api.addClass('label-danger').text('DOWN');
            }
        });
    }

    $('#btn_refresh_status').click(refreshStatus);
    refreshStatus();
    setInterval(refreshStatus, 4000);
});
</script>
