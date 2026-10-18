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

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - Dashboard API Secret (9090)') }}</h2>
        <p class="text-muted">{{ lang._('Secret for the bundled dashboard (http://127.0.0.1:9090/ui/) and the external controller API.') }}</p>
        <hr/>
    </div>

    <div class="col-xs-12">
        <div class="form-group">
            <label>{{ lang._('Current Secret (masked)') }}</label>
            <div>
                <code id="api_secret_masked" style="font-size: 13px;">{{ lang._('Loading...') }}</code>
            </div>
            <span class="help-block">{{ lang._('Use this secret to sign in to the dashboard at port 9090. Note: By default the external controller listens on 127.0.0.1 only; LAN access requires an SSH tunnel or waiting for future LAN API exposure support. Changes are applied to config.yaml, the subscription template and the sub env, then mihomo is hot-reloaded.') }}</span>
        </div>
        <button class="btn btn-default" id="btn_secret_reveal" type="button">
            <i class="fa fa-eye"></i> {{ lang._('Show Secret') }}
        </button>
        <button class="btn btn-warning" id="btn_secret_generate" type="button" style="margin-left: 8px;">
            <i class="fa fa-refresh"></i> {{ lang._('Generate New Secret') }}
        </button>
    </div>

    <div class="col-xs-12" style="margin-top: 15px;">
        <div class="form-group">
            <label for="api_secret_custom">{{ lang._('Set Custom Secret') }}</label>
            <div class="input-group" style="max-width: 480px;">
                <input type="text" class="form-control" id="api_secret_custom" autocomplete="off" spellcheck="false"/>
                <span class="input-group-btn">
                    <button class="btn btn-primary" id="btn_secret_apply" type="button">
                        <b>{{ lang._('Apply') }}</b> <i id="btn_secret_apply_progress"></i>
                    </button>
                </span>
            </div>
            <span class="help-block">{{ lang._('4-128 characters; only letters, digits and . _ ~ @ # % ^ + = : ; , ! ? * - are allowed.') }}</span>
        </div>
    </div>
</div>

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - Subscription') }}</h2>
        <p class="text-muted">{{ lang._('Manage the private subscription source, the automatic update interval and inspect the last update result.') }}</p>
        <hr/>
    </div>

    <div class="col-xs-12">
        <div class="form-group">
            <label for="sub_url">{{ lang._('Subscription URL') }}</label>
            <input type="text" class="form-control" id="sub_url" placeholder="https://..." autocomplete="off" spellcheck="false"/>
            <span class="help-block text-muted" id="sub_url_hint">{{ lang._('Enter an https subscription URL.') }}</span>
        </div>
        <div class="form-group">
            <label>{{ lang._('Current Subscription URL') }}</label>
            <div>
                <code id="sub_url_masked" style="font-size: 13px;">{{ lang._('Not configured') }}</code>
            </div>
            <span class="help-block">{{ lang._('The stored URL is always masked here; the full value is never rendered in the browser.') }}</span>
        </div>
        <div class="checkbox">
            <label>
                <input type="checkbox" id="sub_auto_update"/> {{ lang._('Enable automatic subscription update') }}
            </label>
        </div>
        <div class="form-group">
            <label for="sub_interval">{{ lang._('Update Interval') }}</label>
            <select id="sub_interval" class="form-control" style="max-width: 220px;">
                <option value="o6h">{{ lang._('Every 6 hours') }}</option>
                <option value="o12h">{{ lang._('Every 12 hours') }}</option>
                <option value="o24h">{{ lang._('Every 24 hours') }}</option>
            </select>
        </div>
        <button class="btn btn-primary" id="btn_sub_save" type="button">
            <b>{{ lang._('Save Subscription') }}</b> <i id="btn_sub_save_progress"></i>
        </button>
        <button class="btn btn-info" id="btn_sub_update" type="button" style="margin-left: 8px;">
            <i class="fa fa-cloud-download" id="btn_sub_update_icon"></i> {{ lang._('Update Now') }}
        </button>
    </div>

    <div class="col-xs-12" id="sub_state" style="margin-top: 15px;">
        <table class="table table-condensed table-bordered" style="margin-bottom: 0;">
            <tbody>
                <tr>
                    <th style="width: 220px;">{{ lang._('Last Update Time') }}</th>
                    <td id="sub_state_time">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Last Update Result') }}</th>
                    <td><span id="sub_state_result" class="label label-default">-</span></td>
                </tr>
                <tr>
                    <th>{{ lang._('Node Count') }}</th>
                    <td id="sub_state_nodes">-</td>
                </tr>
                <tr>
                    <th>{{ lang._('Result Message') }}</th>
                    <td id="sub_state_message">-</td>
                </tr>
            </tbody>
        </table>
    </div>
</div>

<script>
$(function () {
    var subPollTimer = null;
    var subPollStart = 0;
    var subLastUpdateTime = null;
    var subBaselineTime = null;
    var subHasUrl = false;
    var subUpdateInProgress = false;

    function textBlock(text) {
        return $('<div></div>').text(String(text));
    }

    function messageLines(lines) {
        var $box = $('<div></div>');
        if (Array.isArray(lines)) {
            $.each(lines, function (i, line) {
                $('<div></div>').text(String(line)).appendTo($box);
            });
        }
        return $box;
    }

    function updateStatus() {
        ajaxGet('/api/mihomo/service/status', {}, function (data) {
            var $badge = $('#service_status_badge');
            if (data.status === 'running') {
                $badge.removeClass('label-default label-danger').addClass('label-success').html('<i class="fa fa-check-circle"></i> ' + '{{ lang._("Running") }}');
            } else {
                $badge.removeClass('label-default label-success').addClass('label-danger').html('<i class="fa fa-times-circle"></i> ' + '{{ lang._("Stopped") }}');
            }
        });
    }

    function loadSecretMasked() {
        ajaxGet('/api/mihomo/general/getGeneral', {}, function (data) {
            var masked = '';
            if (data && data.mihomo && data.mihomo.general) {
                masked = data.mihomo.general.secret_masked || '';
            } else if (data && data.general) {
                masked = data.general.secret_masked || '';
            }
            $('#api_secret_masked').text(masked || 'NOT_CONFIGURED');
        });
    }

    function showSecretDialog(title, secret) {
        var $input = $('<input type="text" class="form-control" readonly style="font-family: Menlo, Monaco, Consolas, monospace;"/>').val(secret);
        var $wrap = $('<div></div>');
        $('<p></p>').text('{{ lang._("Copy this secret to sign in to the dashboard at port 9090:") }}').appendTo($wrap);
        $input.appendTo($wrap);
        BootstrapDialog.show({
            type: BootstrapDialog.TYPE_INFO,
            title: title,
            message: $wrap,
            onshown: function (dialog) {
                $input.on('focus click', function () { this.select(); });
                $input.focus();
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
                    message: textBlock(data.response || '{{ lang._("Action executed successfully.") }}')
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: textBlock(data.message || '{{ lang._("Action failed.") }}')
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
        var $button = $('#btn_save');
        $progress.addClass('fa fa-spinner fa-pulse');
        $button.prop('disabled', true);
        saveFormToEndpoint('/api/mihomo/general/setGeneral', 'frm_general_settings', function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            updateStatus();
            var failed = (data && data.status === 'failed');
            var $message = messageLines(failed ? [] : (data ? data.messages : []));
            if ($message.children().length === 0) {
                if (failed) {
                    $message.text(data && data.message ? data.message : '{{ lang._("Failed to save settings.") }}');
                } else {
                    $message.text('{{ lang._("Settings saved.") }}');
                }
            }
            BootstrapDialog.show({
                type: failed ? BootstrapDialog.TYPE_DANGER : BootstrapDialog.TYPE_SUCCESS,
                title: failed ? '{{ lang._("Error") }}' : '{{ lang._("Saved") }}',
                message: $message
            });
        }, true, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            updateStatus();
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_DANGER,
                title: '{{ lang._("Error") }}',
                message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to save settings.") }}')
            });
        });
    });

    function setSubUpdating(active) {
        subUpdateInProgress = active;
        $('#btn_sub_update').prop('disabled', active);
        $('#btn_sub_update_icon').removeClass('fa-cloud-download fa-spinner fa-pulse');
        $('#btn_sub_update_icon').addClass(active ? 'fa-spinner fa-pulse' : 'fa-cloud-download');
    }

    function flagEnabled(value) {
        return (value === true || value === 1 || value === '1' || value === 'true') ? '1' : '0';
    }

    function renderLastUpdate(lastUpdate) {
        var $badge = $('#sub_state_result');
        $badge.removeClass('label-default label-success label-danger label-warning');
        if (!lastUpdate || typeof lastUpdate !== 'object') {
            subLastUpdateTime = null;
            $('#sub_state_time').text('-');
            $('#sub_state_nodes').text('-');
            $('#sub_state_message').text('-');
            $badge.addClass('label-default').text('-');
            return;
        }
        subLastUpdateTime = lastUpdate.time ? String(lastUpdate.time) : null;
        $('#sub_state_time').text(lastUpdate.time ? String(lastUpdate.time) : '-');
        $('#sub_state_nodes').text((lastUpdate.nodes !== undefined && lastUpdate.nodes !== null) ? String(lastUpdate.nodes) : '-');
        $('#sub_state_message').text(lastUpdate.message ? String(lastUpdate.message) : '-');
        var result = (lastUpdate.result ? String(lastUpdate.result) : '').toLowerCase();
        if (result === 'success') {
            $badge.addClass('label-success').text('{{ lang._("Success") }}');
        } else if (result === 'failed') {
            $badge.addClass('label-danger').text('{{ lang._("Failed") }}');
        } else if (result.length > 0) {
            $badge.addClass('label-warning').text(result);
        } else {
            $badge.addClass('label-default').text('-');
        }
    }

    function applySubscription(sub) {
        sub = sub || {};
        var masked = (typeof sub.url_masked === 'string') ? sub.url_masked : '';
        subHasUrl = (flagEnabled(sub.has_url) === '1') || (masked.length > 0);
        $('#sub_url_masked').text(masked.length > 0 ? masked : '{{ lang._("Not configured") }}');
        if (subHasUrl) {
            $('#sub_url').val('');
            $('#sub_url_hint').removeClass('text-muted').addClass('text-info').text('{{ lang._("A subscription URL is already configured. Leave this field empty to keep it unchanged.") }}');
        } else {
            $('#sub_url_hint').removeClass('text-info').addClass('text-muted').text('{{ lang._("Enter an https subscription URL.") }}');
        }
        $('#sub_auto_update').prop('checked', flagEnabled(sub.auto_update) === '1');
        var interval = sub.auto_interval ? String(sub.auto_interval) : 'o24h';
        if (interval !== 'o6h' && interval !== 'o12h' && interval !== 'o24h') {
            interval = 'o24h';
        }
        $('#sub_interval').val(interval);
    }

    function loadSubscription(applyForm) {
        ajaxGet('/api/mihomo/subscription/get', {}, function (data) {
            if (!data || data.status !== 'ok') {
                return;
            }
            if (applyForm !== false) {
                applySubscription(data.subscription);
            }
            renderLastUpdate(data.last_update);
        });
    }

    function stopSubPolling(finished) {
        if (subPollTimer !== null) {
            clearInterval(subPollTimer);
            subPollTimer = null;
        }
        setSubUpdating(false);
        if (finished === true) {
            loadSubscription(false);
        }
    }

    function startSubPolling() {
        if (subPollTimer !== null) {
            clearInterval(subPollTimer);
            subPollTimer = null;
        }
        subPollStart = (new Date()).getTime();
        setSubUpdating(true);
        $('#sub_state_message').text('{{ lang._("Update triggered, waiting for the result...") }}');
        subPollTimer = setInterval(function () {
            if (((new Date()).getTime() - subPollStart) > 1200000) {
                stopSubPolling(false);
                $('#sub_state_message').text('{{ lang._("The update is still running. Refresh this page later to see the result.") }}');
                return;
            }
            ajaxGet('/api/mihomo/subscription/get', {}, function (data) {
                if (!data || data.status !== 'ok' || !data.last_update) {
                    return;
                }
                var result = (data.last_update.result ? String(data.last_update.result) : '').toLowerCase();
                var updateTime = data.last_update.time ? String(data.last_update.time) : '';
                var changed = (subBaselineTime === null) || (updateTime !== subBaselineTime);
                if (!changed) {
                    /* 状态文件仍是触发前那一轮的结果，保持“等待中”提示 */
                    return;
                }
                renderLastUpdate(data.last_update);
                if (result === 'success' || result === 'failed') {
                    stopSubPolling(false);
                }
            });
        }, 3000);
    }

    $('#btn_sub_save').click(function () {
        var url = $.trim($('#sub_url').val() || '');
        if (url.length > 0 && url.indexOf('https://') !== 0) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_DANGER,
                title: '{{ lang._("Error") }}',
                message: textBlock('{{ lang._("The subscription URL must start with https://.") }}')
            });
            return;
        }
        if (url.length === 0 && !subHasUrl) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("Error") }}',
                message: textBlock('{{ lang._("Please enter a subscription URL.") }}')
            });
            return;
        }
        var payload = {
            auto_update: $('#sub_auto_update').is(':checked') ? '1' : '0',
            auto_interval: $('#sub_interval').val()
        };
        if (url.length > 0) {
            payload.url = url;
        }
        var $progress = $('#btn_sub_save_progress');
        var $button = $('#btn_sub_save');
        $progress.addClass('fa fa-spinner fa-pulse');
        $button.prop('disabled', true);
        ajaxCall('/api/mihomo/subscription/set', payload, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            if (data && data.status === 'ok') {
                if (typeof data.url_masked === 'string' && data.url_masked.length > 0) {
                    $('#sub_url_masked').text(data.url_masked);
                }
                if (url.length > 0) {
                    subHasUrl = true;
                }
                $('#sub_url').val('');
                $('#sub_url_hint').removeClass('text-muted').addClass('text-info').text('{{ lang._("A subscription URL is already configured. Leave this field empty to keep it unchanged.") }}');
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("Saved") }}',
                    message: textBlock(data.message || '{{ lang._("Subscription settings saved.") }}')
                });
                loadSubscription(false);
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to save subscription settings.") }}')
                });
            }
        });
    });

    $('#btn_sub_update').click(function () {
        if (subUpdateInProgress) {
            return;
        }
        setSubUpdating(true);
        ajaxCall('/api/mihomo/subscription/update', {}, function (data) {
            var status = (data && data.status) ? data.status : 'failed';
            if (status === 'triggered') {
                subBaselineTime = subLastUpdateTime;
                startSubPolling();
            } else if (status === 'busy') {
                setSubUpdating(false);
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_WARNING,
                    title: '{{ lang._("Subscription Update") }}',
                    message: textBlock('{{ lang._("An update is already running. Please wait for it to finish.") }}')
                });
            } else {
                setSubUpdating(false);
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to trigger the subscription update.") }}')
                });
            }
        });
    });

    $('#btn_secret_reveal').click(function () {
        ajaxCall('/api/mihomo/general/secretReveal', {}, function (data) {
            if (data && data.status === 'ok') {
                showSecretDialog('{{ lang._("Dashboard API Secret") }}', data.secret);
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to read the API secret.") }}')
                });
            }
        });
    });

    $('#btn_secret_generate').click(function () {
        BootstrapDialog.confirm(
            '{{ lang._("Generate a new secret and hot-reload mihomo? The old secret stops working immediately.") }}',
            function (confirmed) {
                if (!confirmed) {
                    return;
                }
                ajaxCall('/api/mihomo/general/regenerateSecret', {}, function (data) {
                    if (data && data.status === 'ok') {
                        if (typeof data.secret_masked === 'string' && data.secret_masked.length > 0) {
                            $('#api_secret_masked').text(data.secret_masked);
                        }
                        showSecretDialog('{{ lang._("New API Secret") }}', data.secret || '');
                    } else {
                        BootstrapDialog.show({
                            type: BootstrapDialog.TYPE_DANGER,
                            title: '{{ lang._("Error") }}',
                            message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to generate a new secret.") }}')
                        });
                    }
                });
            }
        );
    });

    $('#btn_secret_apply').click(function () {
        var secret = $('#api_secret_custom').val();
        if (secret.length < 4 || secret.length > 128) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("Error") }}',
                message: textBlock('{{ lang._("The secret must be 4-128 characters long.") }}')
            });
            return;
        }
        if (!/^[A-Za-z0-9._~@#%^+=:;,!?*-]+$/.test(secret)) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("Error") }}',
                message: textBlock('{{ lang._("Only letters, digits and . _ ~ @ # % ^ + = : ; , ! ? * - are allowed.") }}')
            });
            return;
        }
        var $progress = $('#btn_secret_apply_progress');
        var $button = $('#btn_secret_apply');
        $progress.addClass('fa fa-spinner fa-pulse');
        $button.prop('disabled', true);
        ajaxCall('/api/mihomo/general/secretSet', { secret: secret }, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            if (data && data.status === 'ok') {
                $('#api_secret_custom').val('');
                if (typeof data.secret_masked === 'string' && data.secret_masked.length > 0) {
                    $('#api_secret_masked').text(data.secret_masked);
                }
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("Saved") }}',
                    message: textBlock(data.message || '{{ lang._("API secret updated.") }}')
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("Error") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("Failed to update the API secret.") }}')
                });
            }
        });
    });

    loadSubscription(true);
    loadSecretMasked();
    setInterval(updateStatus, 5000);
});
</script>
