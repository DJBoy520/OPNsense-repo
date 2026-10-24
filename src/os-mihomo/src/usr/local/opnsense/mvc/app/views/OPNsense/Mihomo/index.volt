{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

{{ partial('OPNsense/Mihomo/styles') }}

<div class="mihomo-page">
    <!-- 卡片 1：服务控制 -->
    <div class="content-box">
        <div class="col-xs-12">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-cogs"></i> {{ lang._('服务控制') }}</span>
            </h2>
            <p class="mihomo-subtitle">{{ lang._('控制 Mihomo 守护进程的运行状态，并查看实时服务状态。') }}</p>
            <hr/>
        </div>

        <!-- 服务控制按钮工具栏 -->
        <div class="col-xs-12 mihomo-toolbar" style="margin-bottom: 15px;">
            <div class="btn-group">
                <button class="btn btn-success" id="btn_start" type="button">
                    <i class="fa fa-play"></i> {{ lang._('启动') }}
                </button>
                <button class="btn btn-danger" id="btn_stop" type="button">
                    <i class="fa fa-stop"></i> {{ lang._('停止') }}
                </button>
                <button class="btn btn-warning" id="btn_restart" type="button">
                    <i class="fa fa-refresh"></i> {{ lang._('重启') }}
                </button>
                <button class="btn btn-info" id="btn_reload" type="button">
                    <i class="fa fa-retweet"></i> {{ lang._('重载') }}
                </button>
            </div>
            <span id="service_status_badge" class="label label-default" style="margin-left: 10px; font-size: 13px; padding: 6px 10px;">
                <i class="fa fa-circle-o-notch fa-spin"></i> {{ lang._('检查中...') }}
            </span>
        </div>
        <div class="clearfix"></div>
    </div>

    <!-- 卡片 2：运行参数 -->
    <div class="content-box">
        <div class="col-xs-12">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-sliders"></i> {{ lang._('运行参数') }}</span>
            </h2>
            <p class="mihomo-subtitle">{{ lang._('配置 Mihomo 透明代理、网络监听以及核心服务运行参数。') }}</p>
            <hr/>
        </div>

        <div class="col-xs-12">
            {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general_settings']) }}
            <hr />
            <button class="btn btn-primary" id="btn_save" type="button">
                <b>{{ lang._('保存并应用') }}</b> <i id="btn_save_progress"></i>
            </button>
        </div>
        <div class="clearfix"></div>
    </div>

    <!-- 卡片 3：面板与 API -->
    <div class="content-box">
        <div class="col-xs-12">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-tachometer"></i> {{ lang._('面板与 API') }} <span id="api_header_port" class="text-muted" style="font-size: 16px;"></span></span>
            </h2>
            <p class="mihomo-subtitle" id="api_panel_desc">{{ lang._('外部控制 API 访问凭据、监听参数以及控制面板连接指南。') }}</p>
            <hr/>
        </div>

        <div class="col-xs-12">
            <div class="form-group">
                <label>{{ lang._('当前密钥（掩码）') }}</label>
                <div>
                    <code id="api_secret_masked" class="mihomo-mono" style="font-size: 13px;">{{ lang._('加载中...') }}</code>
                </div>
                <span class="help-block" id="api_secret_help">{{ lang._('用于登录 Web 控制台及外部控制器 API。修改后将同步写入 config.yaml、订阅模板与 sub 环境变量，并热重载生效。') }}</span>
            </div>
            <div class="alert alert-info" id="api_dashboard_guide" style="margin-bottom: 15px;">
                <strong><i class="fa fa-info-circle"></i> {{ lang._('面板与客户端访问指南') }}：</strong>
                <div id="api_guide_content" style="margin-top: 5px;">
                    <span>{{ lang._('内置面板') }}：<a id="api_bundled_link" href="#" target="_blank" rel="noopener noreferrer">http://<span class="api_disp_host">127.0.0.1</span>:<span class="api_disp_port">9090</span>/ui/</a></span><br/>
                    <span>{{ lang._('Metacubexd / 外部客户端') }}：{{ lang._('主机') }}：<code>http://<span class="api_disp_host">127.0.0.1</span>:<span class="api_disp_port">9090</span></code>，{{ lang._('密钥') }}：{{ lang._('点击 [查看密钥] 复制') }}</span>
                    <div id="api_wan_warn" class="text-warning" style="display: none; margin-top: 4px;">
                        <i class="fa fa-exclamation-triangle"></i> {{ lang._('0.0.0.0 会在全部网络接口（IPv4+IPv6）上监听。请确保外部 WAN 防火墙规则阻断未授权流量；强烈建议绑定至 LAN 接口 IP。') }}
                    </div>
                </div>
            </div>
            <button class="btn btn-default" id="btn_secret_reveal" type="button">
                <i class="fa fa-eye"></i> {{ lang._('查看密钥') }}
            </button>
            <button class="btn btn-warning" id="btn_secret_generate" type="button" style="margin-left: 8px;">
                <i class="fa fa-refresh"></i> {{ lang._('生成新密钥') }}
            </button>
        </div>

        <div class="col-xs-12" style="margin-top: 15px;">
            <div class="form-group">
                <label for="api_secret_custom">{{ lang._('设置自定义密钥') }}</label>
                <div class="input-group" style="max-width: 480px;">
                    <input type="text" class="form-control" id="api_secret_custom" autocomplete="off" spellcheck="false"/>
                    <span class="input-group-btn">
                        <button class="btn btn-primary" id="btn_secret_apply" type="button">
                            <b>{{ lang._('应用') }}</b> <i id="btn_secret_apply_progress"></i>
                        </button>
                    </span>
                </div>
                <span class="help-block">{{ lang._('4-128 个字符；仅允许字母、数字以及 . _ ~ @ # % ^ + = : ; , ! ? * -') }}</span>
            </div>
        </div>
        <div class="clearfix"></div>
    </div>

    <!-- 卡片 4：订阅与策略 -->
    <div class="content-box">
        <div class="col-xs-12">
            <h2 class="mihomo-card-title">
                <span><i class="fa fa-rss"></i> {{ lang._('订阅与策略') }}</span>
            </h2>
            <p class="mihomo-subtitle">{{ lang._('管理远程订阅源、策略组模式、自动更新并在下方查看同步结果。') }}</p>
            <hr/>
        </div>

        <div class="col-xs-12">
            <div class="form-group">
                <label for="sub_url">{{ lang._('订阅地址') }}</label>
                <input type="text" class="form-control" id="sub_url" placeholder="https://..." autocomplete="off" spellcheck="false"/>
                <span class="help-block text-muted" id="sub_url_hint">{{ lang._('请输入 https 订阅地址。') }}</span>
            </div>
            <div class="form-group">
                <label>{{ lang._('当前订阅（掩码）') }}</label>
                <div>
                    <code id="sub_url_masked" class="mihomo-mono" style="font-size: 13px;">{{ lang._('未配置') }}</code>
                </div>
                <span class="help-block">{{ lang._('存储的 URL 在此已脱敏展示；完整地址绝不输出至浏览器。') }}</span>
            </div>
            <div class="checkbox">
                <label>
                    <input type="checkbox" id="sub_auto_update"/> {{ lang._('启用自动更新') }}
                </label>
            </div>
            <div class="form-group">
                <label for="sub_interval">{{ lang._('更新周期') }}</label>
                <select id="sub_interval" class="form-control" style="max-width: 260px;">
                    <option value="o6h">{{ lang._('每 6 小时') }}</option>
                    <option value="o12h">{{ lang._('每 12 小时') }}</option>
                    <option value="o24h">{{ lang._('每 24 小时') }}</option>
                </select>
            </div>
            <div class="form-group">
                <label for="sub_strategy">{{ lang._('策略来源') }}</label>
                <select id="sub_strategy" class="form-control" style="max-width: 380px;">
                    <option value="subscription">{{ lang._('沿用订阅自带策略组与规则（推荐）') }}</option>
                    <option value="template">{{ lang._('插件内置策略组与规则') }}</option>
                </select>
                <span class="help-block">{{ lang._('沿用订阅时，代理组与分流规则与 Windows/Clash 客户端一致；订阅缺少 proxy-groups 或 rules 时自动回退插件模板。切换后建议点「立即更新」。') }}</span>
            </div>
            <button class="btn btn-primary" id="btn_sub_save" type="button">
                <b>{{ lang._('保存订阅') }}</b> <i id="btn_sub_save_progress"></i>
            </button>
            <button class="btn btn-info" id="btn_sub_update" type="button" style="margin-left: 8px;">
                <i class="fa fa-cloud-download" id="btn_sub_update_icon"></i> {{ lang._('立即更新') }}
            </button>
        </div>

        <div class="col-xs-12" id="sub_state" style="margin-top: 20px;">
            <table class="table table-condensed table-bordered" style="margin-bottom: 0;">
                <tbody>
                    <tr>
                        <th style="width: 220px;">{{ lang._('最近更新时间') }}</th>
                        <td id="sub_state_time">-</td>
                    </tr>
                    <tr>
                        <th>{{ lang._('最近更新结果') }}</th>
                        <td><span id="sub_state_result" class="label label-default">-</span></td>
                    </tr>
                    <tr>
                        <th>{{ lang._('节点数量') }}</th>
                        <td id="sub_state_nodes">-</td>
                    </tr>
                    <tr>
                        <th>{{ lang._('策略来源') }}</th>
                        <td id="sub_state_strategy">-</td>
                    </tr>
                    <tr>
                        <th>{{ lang._('策略组数量') }}</th>
                        <td id="sub_state_groups">-</td>
                    </tr>
                    <tr>
                        <th>{{ lang._('分流规则数量') }}</th>
                        <td id="sub_state_rules">-</td>
                    </tr>
                    <tr>
                        <th>{{ lang._('结果消息') }}</th>
                        <td id="sub_state_message">-</td>
                    </tr>
                </tbody>
            </table>
        </div>
        <div class="clearfix"></div>
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
                $badge.removeClass('label-default label-danger').addClass('label-success').html('<i class="fa fa-check-circle"></i> ' + '{{ lang._("运行中") }}');
            } else {
                $badge.removeClass('label-default label-success').addClass('label-danger').html('<i class="fa fa-times-circle"></i> ' + '{{ lang._("已停止") }}');
            }
        });
    }

    var currentApiBind = '127.0.0.1';
    var currentApiPort = '9090';

    function updateApiDisplay(bind, port) {
        currentApiBind = bind || '127.0.0.1';
        currentApiPort = port || '9090';
        var dispHost = (currentApiBind === '0.0.0.0') ? window.location.hostname : currentApiBind;
        var fullAddr = dispHost + ':' + currentApiPort;
        $('#api_header_port').text('(' + currentApiPort + ')');
        $('.api_disp_host').text(dispHost);
        $('.api_disp_port').text(currentApiPort);
        $('#api_bundled_link').attr('href', 'http://' + fullAddr + '/ui/').text('http://' + fullAddr + '/ui/');
        if (currentApiBind === '0.0.0.0') {
            $('#api_wan_warn').show();
        } else {
            $('#api_wan_warn').hide();
        }
    }

    function loadSecretMasked() {
        ajaxGet('/api/mihomo/general/getGeneral', {}, function (data) {
            var gen = (data && data.mihomo && data.mihomo.general) ? data.mihomo.general : ((data && data.general) ? data.general : {});
            var masked = gen.secret_masked || '';
            $('#api_secret_masked').text(masked || '{{ lang._("未配置") }}');
            var bind = gen.api_bind || '127.0.0.1';
            var port = gen.api_port || '9090';
            updateApiDisplay(bind, port);
        });
    }

    function showSecretDialog(title, secret) {
        var $input = $('<input type="text" class="form-control" readonly style="font-family: Menlo, Monaco, Consolas, monospace;"/>').val(secret);
        var $wrap = $('<div></div>');
        var dispHost = (currentApiBind === '0.0.0.0') ? window.location.hostname : currentApiBind;
        $('<p></p>').text('{{ lang._("使用此密钥登录 Web 控制台 / Metacubexd（地址 ") }}' + dispHost + ':' + currentApiPort + '）：').appendTo($wrap);
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
                    title: '{{ lang._("服务控制") }}',
                    message: textBlock(data.response || '{{ lang._("操作执行成功。") }}')
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock(data.message || '{{ lang._("操作失败。") }}')
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
                    $message.text(data && data.message ? data.message : '{{ lang._("保存设置失败。") }}');
                } else {
                    $message.text('{{ lang._("设置已保存。") }}');
                }
            }
            BootstrapDialog.show({
                type: failed ? BootstrapDialog.TYPE_DANGER : BootstrapDialog.TYPE_SUCCESS,
                title: failed ? '{{ lang._("错误") }}' : '{{ lang._("保存成功") }}',
                message: $message
            });
            loadSecretMasked();
        }, true, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            updateStatus();
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_DANGER,
                title: '{{ lang._("错误") }}',
                message: textBlock(data && data.message ? data.message : '{{ lang._("保存设置失败。") }}')
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
            $('#sub_state_strategy').text('-');
            $('#sub_state_groups').text('-');
            $('#sub_state_rules').text('-');
            $('#sub_state_message').text('-');
            $badge.addClass('label-default').text('-');
            return;
        }
        subLastUpdateTime = lastUpdate.time ? String(lastUpdate.time) : null;
        $('#sub_state_time').text(lastUpdate.time ? String(lastUpdate.time) : '-');
        $('#sub_state_nodes').text((lastUpdate.nodes !== undefined && lastUpdate.nodes !== null) ? String(lastUpdate.nodes) : '-');
        $('#sub_state_strategy').text(lastUpdate.strategy === 'subscription' ? '订阅自带' : '插件模板');
        $('#sub_state_groups').text((lastUpdate.groups !== undefined && lastUpdate.groups !== null && lastUpdate.groups !== '') ? String(lastUpdate.groups) : '-');
        $('#sub_state_rules').text((lastUpdate.rules !== undefined && lastUpdate.rules !== null && lastUpdate.rules !== '') ? String(lastUpdate.rules) : '-');
        $('#sub_state_message').text(lastUpdate.message ? String(lastUpdate.message) : '-');
        var result = (lastUpdate.result ? String(lastUpdate.result) : '').toLowerCase();
        if (result === 'success') {
            $badge.addClass('label-success').text('{{ lang._("成功") }}');
        } else if (result === 'failed') {
            $badge.addClass('label-danger').text('{{ lang._("失败") }}');
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
        $('#sub_url_masked').text(masked.length > 0 ? masked : '{{ lang._("未配置") }}');
        if (subHasUrl) {
            $('#sub_url').val('');
            $('#sub_url_hint').removeClass('text-muted').addClass('text-info').text('{{ lang._("已配置订阅地址。留空则保持现有地址不变。") }}');
        } else {
            $('#sub_url_hint').removeClass('text-info').addClass('text-muted').text('{{ lang._("请输入 https 订阅地址。") }}');
        }
        $('#sub_auto_update').prop('checked', flagEnabled(sub.auto_update) === '1');
        var interval = sub.auto_interval ? String(sub.auto_interval) : 'o24h';
        if (interval !== 'o6h' && interval !== 'o12h' && interval !== 'o24h') {
            interval = 'o24h';
        }
        $('#sub_interval').val(interval);
        $('#sub_strategy').val(sub.strategy === 'template' ? 'template' : 'subscription');
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
        $('#sub_state_message').text('{{ lang._("已触发更新，正在等待结果...") }}');
        subPollTimer = setInterval(function () {
            if (((new Date()).getTime() - subPollStart) > 1200000) {
                stopSubPolling(false);
                $('#sub_state_message').text('{{ lang._("更新仍在后台执行，请稍后刷新页面查看结果。") }}');
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
                title: '{{ lang._("错误") }}',
                message: textBlock('{{ lang._("订阅地址必须以 https:// 开头。") }}')
            });
            return;
        }
        if (url.length === 0 && !subHasUrl) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("错误") }}',
                message: textBlock('{{ lang._("请输入订阅地址。") }}')
            });
            return;
        }
        var payload = {
            auto_update: $('#sub_auto_update').is(':checked') ? '1' : '0',
            auto_interval: $('#sub_interval').val(),
            strategy: $('#sub_strategy').val()
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
                $('#sub_url_hint').removeClass('text-muted').addClass('text-info').text('{{ lang._("已配置订阅地址。留空则保持现有地址不变。") }}');
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("保存成功") }}',
                    message: textBlock(data.message || '{{ lang._("订阅设置已保存。") }}')
                });
                loadSubscription(false);
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("保存订阅设置失败。") }}')
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
                    title: '{{ lang._("订阅更新") }}',
                    message: textBlock('{{ lang._("当前已有更新任务正在运行，请等待其完成。") }}')
                });
            } else {
                setSubUpdating(false);
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("触发订阅更新失败。") }}')
                });
            }
        });
    });

    $('#btn_secret_reveal').click(function () {
        ajaxCall('/api/mihomo/general/secretReveal', {}, function (data) {
            if (data && data.status === 'ok') {
                showSecretDialog('{{ lang._("查看 API 密钥") }}', data.secret);
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("获取 API 密钥失败。") }}')
                });
            }
        });
    });

    $('#btn_secret_generate').click(function () {
        BootstrapDialog.confirm(
            '{{ lang._("生成新密钥并热重载 Mihomo？旧密钥将立即失效。") }}',
            function (confirmed) {
                if (!confirmed) {
                    return;
                }
                ajaxCall('/api/mihomo/general/regenerateSecret', {}, function (data) {
                    if (data && data.status === 'ok') {
                        if (typeof data.secret_masked === 'string' && data.secret_masked.length > 0) {
                            $('#api_secret_masked').text(data.secret_masked);
                        }
                        showSecretDialog('{{ lang._("新 API 密钥") }}', data.secret || '');
                    } else {
                        BootstrapDialog.show({
                            type: BootstrapDialog.TYPE_DANGER,
                            title: '{{ lang._("错误") }}',
                            message: textBlock(data && data.message ? data.message : '{{ lang._("生成新密钥失败。") }}')
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
                title: '{{ lang._("错误") }}',
                message: textBlock('{{ lang._("密钥长度必须为 4-128 个字符。") }}')
            });
            return;
        }
        if (!/^[A-Za-z0-9._~@#%^+=:;,!?*-]+$/.test(secret)) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("错误") }}',
                message: textBlock('{{ lang._("仅允许字母、数字以及 . _ ~ @ # % ^ + = : ; , ! ? * -") }}')
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
                    title: '{{ lang._("保存成功") }}',
                    message: textBlock(data.message || '{{ lang._("API 密钥已更新。") }}')
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock(data && data.message ? data.message : '{{ lang._("更新 API 密钥失败。") }}')
                });
            }
        });
    });

    loadSubscription(true);
    loadSecretMasked();
    setInterval(updateStatus, 5000);
});
</script>
