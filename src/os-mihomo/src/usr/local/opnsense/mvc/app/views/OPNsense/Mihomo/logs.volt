{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - Live Log Viewer') }}</h2>
        <p class="text-muted">{{ lang._('Real-time filtered logs from Mihomo core daemon with sensitive credential masking.') }}</p>
        <hr/>
    </div>

    <div class="col-xs-12 form-inline" style="margin-bottom: 12px;">
        <label for="log_level_filter" style="margin-right: 8px;">{{ lang._('Log Level Filter:') }}</label>
        <select id="log_level_filter" class="selectpicker" data-width="140px">
            <option value="all" selected>{{ lang._('All Levels') }}</option>
            <option value="debug">Debug</option>
            <option value="info">Info</option>
            <option value="warning">Warning</option>
            <option value="error">Error</option>
        </select>

        <label for="log_limit" style="margin-left: 15px; margin-right: 8px;">{{ lang._('Lines:') }}</label>
        <select id="log_limit" class="selectpicker" data-width="100px">
            <option value="100">100</option>
            <option value="200" selected>200</option>
            <option value="500">500</option>
            <option value="1000">1000</option>
        </select>

        <button class="btn btn-default" id="btn_refresh_logs" type="button" style="margin-left: 15px;">
            <i class="fa fa-refresh"></i> {{ lang._('Refresh') }}
        </button>

        <label style="margin-left: 15px; font-weight: normal;">
            <input type="checkbox" id="chk_auto_refresh" checked> {{ lang._('Auto Refresh (5s)') }}
        </label>
    </div>

    <div class="col-xs-12">
        <textarea readonly id="mihomo_log_viewer" rows="22" class="form-control" style="font-family: Menlo, Monaco, Consolas, 'Courier New', monospace; font-size: 13px; line-height: 1.3; background-color: #222; color: #eee; border: 1px solid #444; resize: vertical;"></textarea>
    </div>
</div>

<script>
$(function () {
    $('.selectpicker').selectpicker('refresh');

    function fetchLogs() {
        var level = $('#log_level_filter').val();
        var limit = $('#log_limit').val();
        ajaxCall('/api/mihomo/logs/getLogs', {level: level, limit: limit}, function (data) {
            var $viewer = $('#mihomo_log_viewer');
            if (data.status === 'ok' && Array.isArray(data.logs)) {
                var content = data.logs.map(function(item) {
                    return item.msg;
                }).join('\n');
                $viewer.val(content);
                $viewer.scrollTop($viewer[0].scrollHeight);
            } else {
                $viewer.val('{{ lang._("Failed to fetch logs.") }}');
            }
        });
    }

    $('#log_level_filter, #log_limit').change(fetchLogs);
    $('#btn_refresh_logs').click(fetchLogs);

    fetchLogs();

    setInterval(function () {
        if ($('#chk_auto_refresh').is(':checked')) {
            fetchLogs();
        }
    }, 5000);
});
</script>
