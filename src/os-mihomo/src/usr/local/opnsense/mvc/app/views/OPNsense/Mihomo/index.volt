{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - General Settings') }}</h2>
        <p class="text-muted">{{ lang._('Configure Mihomo transparent proxy and service parameters.') }}</p>
        <hr/>
    </div>

    <!-- Service control button toolbar -->
    <div class="col-xs-12" style="margin-bottom: 15px;">
        <div class="btn-group">
            <button class="btn btn-success" id="btn_start" type="button">
                <i class="fa fa-play"></i> {{ lang._('Start') }}
            </button>
            <button class="btn btn-danger" id="btn_stop" type="button">
                <i class="fa fa-stop"></i> {{ lang._('Stop') }}
            </button>
            <button class="btn btn-warning" id="btn_restart" type="button">
                <i class="fa fa-refresh"></i> {{ lang._('Restart') }}
            </button>
            <button class="btn btn-info" id="btn_reload" type="button">
                <i class="fa fa-retweet"></i> {{ lang._('Reload') }}
            </button>
        </div>
        <span id="service_status_badge" class="label label-default" style="margin-left: 10px; font-size: 13px; padding: 6px 10px;">
            <i class="fa fa-circle-o-notch fa-spin"></i> {{ lang._('Checking...') }}
        </span>
    </div>

    <div class="col-xs-12">
        {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general_settings']) }}
        <hr />
        <button class="btn btn-primary" id="btn_save" type="button">
            <b>{{ lang._('Save & Apply') }}</b> <i id="btn_save_progress"></i>
        </button>
    </div>
</div>

<script>
$(function () {
    function updateStatus() {
        ajaxCall('/api/mihomo/service/status', {}, function (data) {
            var $badge = $('#service_status_badge');
            if (data.status === 'running') {
                $badge.removeClass('label-default label-danger').addClass('label-success').html('<i class="fa fa-check-circle"></i> ' + '{{ lang._("Running") }}');
            } else {
                $badge.removeClass('label-default label-success').addClass('label-danger').html('<i class="fa fa-times-circle"></i> ' + '{{ lang._("Stopped") }}');
            }
        });
    }

    mapDataToFormUI({'frm_general_settings': '/api/mihomo/general/getGeneral'}).done(function () {
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
        updateStatus();
    });

    function callServiceAction(action) {
        ajaxCall('/api/mihomo/service/' + action, {}, function (data) {
            if (data.status === 'ok') {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("Service Action") }}',
                    message: data.response || '{{ lang._("Action executed successfully.") }}'
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: data.message || '{{ lang._("Action failed.") }}'
                });
            }
            setTimeout(updateStatus, 1000);
        });
    }

    $('#btn_start').click(function() { callServiceAction('start'); });
    $('#btn_stop').click(function() { callServiceAction('stop'); });
    $('#btn_restart').click(function() { callServiceAction('restart'); });
    $('#btn_reload').click(function() { callServiceAction('reload'); });

    $('#btn_save').click(function () {
        var $progress = $('#btn_save_progress');
        $progress.addClass('fa fa-spinner fa-pulse');
        saveFormToEndpoint('/api/mihomo/general/setGeneral', 'frm_general_settings', function () {
            ajaxCall('/api/mihomo/service/restart', {}, function (data) {
                $progress.removeClass('fa fa-spinner fa-pulse');
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("Saved") }}',
                    message: '{{ lang._("Settings saved and service reloaded.") }}'
                });
                updateStatus();
            });
        }, true);
    });

    setInterval(updateStatus, 5000);
});
</script>
