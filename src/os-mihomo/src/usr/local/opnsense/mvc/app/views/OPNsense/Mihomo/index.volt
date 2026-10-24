{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

{{ partial('OPNsense/Mihomo/styles') }}

<div class="mihomo-page">
    <div id="save_toast" class="mihomo-save-toast" style="display: none;"></div>

    <div class="mihomo-tabs-bar">
        <ul class="nav nav-tabs" role="tablist">
            <li class="active" role="presentation"><a href="#tab_overview" data-toggle="tab" role="tab"><i class="fa fa-dashboard"></i> {{ lang._('概览') }}</a></li>
            <li role="presentation"><a href="#tab_general" data-toggle="tab" role="tab"><i class="fa fa-sliders"></i> {{ lang._('基本设置') }}</a></li>
            <li role="presentation"><a href="#tab_subscription" data-toggle="tab" role="tab"><i class="fa fa-rss"></i> {{ lang._('订阅与策略') }}</a></li>
            <li role="presentation"><a href="#tab_api" data-toggle="tab" role="tab"><i class="fa fa-tachometer"></i> {{ lang._('面板与 API') }}</a></li>
        </ul>
    </div>

    <div class="tab-content">
        <!-- Tab 1：概览 -->
        <div class="tab-pane active" id="tab_overview">
            <div class="row">
            <div class="col-md-6">
            <div class="mihomo-card">
                <div class="mihomo-card-head">
                    <h2 class="mihomo-card-title">
                        <span><i class="fa fa-cogs"></i> {{ lang._('系统状态') }}</span>
                        <a class="btn btn-default btn-xs" href="/ui/mihomo/status">
                            <i class="fa fa-heartbeat"></i> {{ lang._('查看运行状态') }}
                        </a>
                    </h2>
                </div>
                <div class="mihomo-card-body">
                    <div class="mihomo-stat-card">
                        <div>
                            <span id="ov_state_dot" class="mihomo-status-dot"></span>
                            <span id="ov_state_text" style="font-weight: 600; margin-left: 6px;">{{ lang._('检查中...') }}</span>
                            <span id="service_status_badge" class="label label-default" style="margin-left: 8px;">
                                <i class="fa fa-circle-o-notch fa-spin"></i> {{ lang._('检查中...') }}
                            </span>
                        </div>
                        <div style="font-size: 13px; color: var(--mh-muted); line-height: 2;">
                            <div>{{ lang._('接入方式') }}：<span id="ov_transport">-</span></div>
                            <div>{{ lang._('内核模式') }}：<span id="ov_core_mode">-</span>
                                 <span style="margin-left: 12px;">{{ lang._('自启') }}：<span id="ov_autostart">-</span></span>
                            </div>
                        </div>
                        <div class="mihomo-toolbar" style="margin-bottom: 0;">
                            <!-- 启动键独立于 btn-group：隐藏组内首个可见按钮时避免 BS3 圆角丢失 -->
                            <button class="btn btn-success" id="btn_start" type="button">
                                <i class="fa fa-play"></i> {{ lang._('启动') }}
                            </button>
                            <div class="btn-group">
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
                        </div>
                    </div>
                </div>
            </div>
            </div>
            <div class="col-md-6">
            <div class="mihomo-card">
                <div class="mihomo-card-head">
                    <h2 class="mihomo-card-title">
                        <span><i class="fa fa-bar-chart"></i> {{ lang._('订阅资源') }}</span>
                        <a class="btn btn-default btn-xs" href="/ui/mihomo/proxies">
                            <i class="fa fa-sitemap"></i> {{ lang._('打开策略组') }}
                        </a>
                    </h2>
                </div>
                <div class="mihomo-card-body">
                    <div class="mihomo-stat-card">
                        <div class="row" style="margin-bottom: 10px;">
                            <div class="col-xs-4" style="text-align: center;">
                                <div class="mihomo-stat-num" id="ov_nodes"><span class="mihomo-skeleton" style="display: inline-block; width: 56px; height: 24px;"></span></div>
                                <div class="mihomo-stat-label">{{ lang._('可用节点') }}</div>
                            </div>
                            <div class="col-xs-4" style="text-align: center;">
                                <div class="mihomo-stat-num" id="ov_groups"><span class="mihomo-skeleton" style="display: inline-block; width: 56px; height: 24px;"></span></div>
                                <div class="mihomo-stat-label">{{ lang._('策略组') }}</div>
                            </div>
                            <div class="col-xs-4" style="text-align: center;">
                                <div class="mihomo-stat-num" id="ov_rules"><span class="mihomo-skeleton" style="display: inline-block; width: 76px; height: 24px;"></span></div>
                                <div class="mihomo-stat-label">{{ lang._('分流规则') }}</div>
                            </div>
                        </div>
                        <div style="font-size: 13px; color: var(--mh-muted); margin-bottom: 10px;">
                            <code id="ov_sub_masked" class="mihomo-mono" style="font-size: 12px;">-</code>
                            <span id="ov_sub_result" class="label label-default" style="margin: 0 6px;">-</span>
                            <span id="ov_sub_time">-</span>
                        </div>
                        <div class="mihomo-toolbar" style="margin-bottom: 0;">
                            <button class="btn btn-default btn-sm" id="ov_btn_sub_update" type="button">
                                <i class="fa fa-cloud-download"></i> {{ lang._('立即同步') }}
                            </button>
                        </div>
                        <div id="ov_sub_msg" class="text-muted" style="font-size: 12px; margin-top: 8px; display: none;"></div>
                    </div>
                </div>
            </div>
            </div>
            </div>
        </div>

        <!-- Tab 2：基本设置 -->
        <div class="tab-pane" id="tab_general">
            <div class="mihomo-card">
                <div class="mihomo-card-head">
                    <h2 class="mihomo-card-title">
                        <span><i class="fa fa-sliders"></i> {{ lang._('运行参数') }}</span>
                    </h2>
                </div>
                <div class="mihomo-card-body">
                    <div class="mihomo-form-wrap mihomo-modern-form">
                        {{ partial("layout_partials/base_form", ['fields': generalForm, 'id': 'frm_general_settings']) }}
                        <div class="mihomo-toolbar" style="margin-top: 15px; margin-bottom: 0;">
                            <button class="btn btn-primary" id="btn_save" type="button">
                                <b>{{ lang._('保存并应用') }}</b> <i id="btn_save_progress"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <!-- Tab 3：订阅与策略 -->
        <div class="tab-pane" id="tab_subscription">
            <div class="mihomo-card">
                <div class="mihomo-card-head">
                    <h2 class="mihomo-card-title">
                        <span><i class="fa fa-rss"></i> {{ lang._('订阅') }}</span>
                    </h2>
                </div>
                <div class="mihomo-card-body">
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

                    <div class="row">
                        <div class="col-xs-12 col-sm-6">
                            <div class="checkbox" style="margin-top: 5px;">
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
                        </div>
                        <div class="col-xs-12 col-sm-6">
                            <div class="form-group">
                                <label>{{ lang._('策略来源') }}</label>
                                <div class="mihomo-radio-cards" id="sub_strategy_cards">
                                    <div class="mihomo-radio-card" data-val="subscription">
                                        <div class="mihomo-radio-indicator"><i class="fa fa-check"></i></div>
                                        <div class="mihomo-radio-content">
                                            <div class="mihomo-radio-title">{{ lang._('沿用订阅自带策略组与规则') }} <span class="label label-success" style="font-size: 11px;">{{ lang._('推荐') }}</span></div>
                                            <div class="mihomo-radio-desc">{{ lang._('代理组与分流规则与客户端一致；缺失时自动回退插件模板。') }}</div>
                                        </div>
                                    </div>
                                    <div class="mihomo-radio-card" data-val="template">
                                        <div class="mihomo-radio-indicator"><i class="fa fa-check"></i></div>
                                        <div class="mihomo-radio-content">
                                            <div class="mihomo-radio-title">{{ lang._('插件内置策略组与规则') }}</div>
                                            <div class="mihomo-radio-desc">{{ lang._('忽略订阅内部策略，由插件内置模板生成。') }}</div>
                                        </div>
                                    </div>
                                </div>
                                <select id="sub_strategy" class="form-control" style="display: none;">
                                    <option value="subscription">{{ lang._('沿用订阅自带策略组与规则（推荐）') }}</option>
                                    <option value="template">{{ lang._('插件内置策略组与规则') }}</option>
                                </select>
                            </div>
                        </div>
                    </div>

                    <div class="mihomo-toolbar" style="margin-top: 10px; margin-bottom: 20px;">
                        <button class="btn btn-primary" id="btn_sub_save" type="button">
                            <b>{{ lang._('保存订阅') }}</b> <i id="btn_sub_save_progress"></i>
                        </button>
                        <button class="btn btn-info" id="btn_sub_update" type="button">
                            <i class="fa fa-cloud-download" id="btn_sub_update_icon"></i> {{ lang._('立即更新') }}
                        </button>
                    </div>

                    <!-- 最近更新结果（紧凑 2 列 kv） -->
                    <div id="sub_state">
                        <div class="mihomo-section-title">
                            <i class="fa fa-history"></i> {{ lang._('最近更新状态') }}
                        </div>
                        <table class="table mihomo-kv">
                            <tbody>
                                <tr>
                                    <th>{{ lang._('更新时间') }}</th>
                                    <td id="sub_state_time">-</td>
                                    <th>{{ lang._('更新结果') }}</th>
                                    <td><span id="sub_state_result" class="label label-default">-</span></td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('节点数量') }}</th>
                                    <td id="sub_state_nodes">-</td>
                                    <th>{{ lang._('策略来源') }}</th>
                                    <td id="sub_state_strategy">-</td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('策略组数量') }}</th>
                                    <td id="sub_state_groups">-</td>
                                    <th>{{ lang._('分流规则数量') }}</th>
                                    <td id="sub_state_rules">-</td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('结果消息') }}</th>
                                    <td colspan="3" id="sub_state_message">-</td>
                                </tr>
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Tab 4：面板与 API -->
        <div class="tab-pane" id="tab_api">
            <div class="mihomo-card">
                <div class="mihomo-card-head">
                    <h2 class="mihomo-card-title">
                        <span><i class="fa fa-tachometer"></i> {{ lang._('面板与 API') }} <span id="api_header_port" class="badge" style="margin-left: 8px; font-weight: normal; background-color: #f0f0f0; color: #555555;"></span></span>
                    </h2>
                </div>
                <div class="mihomo-card-body">
                    <div class="mihomo-section">
                        <div class="mihomo-section-title">
                            <i class="fa fa-link"></i> {{ lang._('访问地址与密钥') }}
                        </div>
                        <table class="table mihomo-kv">
                            <tbody>
                                <tr>
                                    <th>{{ lang._('内置面板') }}</th>
                                    <td>
                                        <a id="api_bundled_link" href="#" target="_blank" rel="noopener noreferrer">-</a>
                                        <button type="button" class="btn btn-xs btn-default mihomo-copy-btn" id="btn_copy_api_endpoint" style="margin-left: 8px;">
                                            <i class="fa fa-clipboard"></i> {{ lang._('复制端点') }}
                                        </button>
                                    </td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('API 端点') }}</th>
                                    <td>
                                        <code id="api_endpoint_display" class="mihomo-mono">-</code>
                                    </td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('当前监听') }}</th>
                                    <td>
                                        <span id="api_bind_badge" class="label label-default mihomo-mono">-</span>
                                    </td>
                                </tr>
                                <tr>
                                    <th>{{ lang._('认证密钥') }}</th>
                                    <td>
                                        <code id="api_secret_masked" class="mihomo-mono" style="font-size: 13px;">{{ lang._('加载中...') }}</code>
                                        <div style="margin-top: 6px;">
                                            <button class="btn btn-xs btn-default" id="btn_secret_reveal" type="button">
                                                <i class="fa fa-eye"></i> {{ lang._('查看密钥') }}
                                            </button>
                                            <button class="btn btn-xs btn-warning" id="btn_secret_generate" type="button" style="margin-left: 6px;">
                                                <i class="fa fa-refresh"></i> {{ lang._('生成新密钥') }}
                                            </button>
                                        </div>
                                        <div class="text-muted" id="api_secret_help" style="font-size: 12px; margin-top: 6px;">
                                            {{ lang._('用于登录 Web 控制台及外部控制器 API。修改后将同步写入配置并热重载生效。') }}
                                        </div>
                                    </td>
                                </tr>
                            </tbody>
                        </table>
                        <div id="api_wan_warn" class="mihomo-callout-warning" style="display: none; margin-top: 10px; margin-bottom: 0;">
                            <i class="fa fa-exclamation-triangle"></i> {{ lang._('已监听全部网络接口（0.0.0.0）。建议仅在 LAN 接口监听并确保 WAN 防火墙阻断未授权流量。') }}
                        </div>
                    </div>

                    <!-- 自定义密钥（折叠） -->
                    <div class="mihomo-section" style="margin-top: 15px;">
                        <a href="#collapse_secret_custom" data-toggle="collapse" class="text-muted" style="text-decoration: none; font-size: 13px;">
                            <i class="fa fa-caret-right"></i> <b>{{ lang._('自定义密钥设置') }}</b>
                        </a>
                        <div id="collapse_secret_custom" class="collapse" style="margin-top: 10px;">
                            <div class="form-group" style="margin-bottom: 0;">
                                <label for="api_secret_custom">{{ lang._('设置自定义密钥') }}</label>
                                <div class="input-group" style="max-width: 480px;">
                                    <input type="text" class="form-control" id="api_secret_custom" autocomplete="off" spellcheck="false"/>
                                    <span class="input-group-btn">
                                        <button class="btn btn-primary" id="btn_secret_apply" type="button">
                                            <b>{{ lang._('应用') }}</b> <i id="btn_secret_apply_progress"></i>
                                        </button>
                                    </span>
                                </div>
                                <span class="help-block" style="font-size: 12px; margin-bottom: 0;">{{ lang._('4-128 个字符；仅允许字母、数字以及 . _ ~ @ # % ^ + = : ; , ! ? * -') }}</span>
                            </div>
                        </div>
                    </div>

                    <!-- 客户端访问指南 -->
                    <div class="mihomo-guide" id="api_dashboard_guide">
                        <strong><i class="fa fa-info-circle"></i> {{ lang._('客户端接入指南') }}</strong>
                        <div id="api_guide_content" style="margin-top: 6px;">
                            <p>{{ lang._('内置面板') }}：<a href="#" class="api_link_preview" target="_blank" rel="noopener noreferrer">http://<span class="api_disp_host">-</span>:<span class="api_disp_port">-</span>/ui/</a></p>
                            <p>{{ lang._('Metacubexd / 外部客户端') }}：{{ lang._('服务器') }} <code>http://<span class="api_disp_host">-</span>:<span class="api_disp_port">-</span></code>，{{ lang._('密钥') }}：{{ lang._('点击 [查看密钥] 复制') }}</p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
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

    /* ---------- Tab 与 URL hash ---------- */

    function isOverviewActive() {
        return $('#tab_overview').hasClass('active');
    }

    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        if (history.replaceState) {
            history.replaceState(null, null, $(e.target).attr('href'));
        }
        $('.selectpicker').selectpicker('refresh');
        if ($(e.target).attr('href') === '#tab_overview') {
            updateStatus(true);
        }
    });

    document.addEventListener('visibilitychange', function () {
        if (!document.hidden && isOverviewActive()) {
            updateStatus(true);
        }
    });

    function restoreTabFromHash() {
        var initialHash = window.location.hash;
        if (!initialHash || initialHash.length < 2) {
            return true;
        }
        try {
            if (!$.fn.tab) {
                return false;
            }
            if ($(initialHash).length === 0) {
                return true;
            }
            var $anchor = $('a[data-toggle="tab"][href="' + initialHash + '"]');
            if ($anchor.length === 0) {
                return true;
            }
            $anchor.tab('show');
            return true;
        } catch (e) {
            /* 非法 hash 选择器：保持默认概览 Tab */
            return true;
        }
    }

    /* Bootstrap tab 插件可能晚于 DOM-ready 就绪：短轮询直到激活成功，window load 兜底 */
    restoreTabFromHash();
    var hashRestoreTries = 0;
    var hashRestoreTimer = setInterval(function () {
        hashRestoreTries += 1;
        if (restoreTabFromHash() || hashRestoreTries > 40) {
            clearInterval(hashRestoreTimer);
        }
    }, 250);
    $(window).on('load', restoreTabFromHash);
    /* 同文档 hash 变化（浏览器前进/后退或手动改地址）也恢复对应 Tab；
       Tab 自身切换走 replaceState，不触发 hashchange，无回环 */
    $(window).on('hashchange', restoreTabFromHash);

    /* ---------- 保存成功横条 ---------- */

    function showSaveToast(msg) {
        var $t = $('#save_toast');
        $t.text(String(msg));
        $t.show();
        setTimeout(function () { $t.hide(); }, 4000);
    }

    /* ---------- 概览：状态 / 主按钮切换 ---------- */

    function renderOverviewState(running) {
        var $dot = $('#ov_state_dot');
        $dot.removeClass('is-running is-stopped is-error');
        if (running) {
            $dot.addClass('is-running');
            $('#ov_state_text').text('{{ lang._("运行中") }}');
            $('#btn_start').hide();
            $('#btn_stop').show();
            $('#btn_restart').show();
            $('#btn_reload').show();
        } else {
            $dot.addClass('is-stopped');
            $('#ov_state_text').text('{{ lang._("已停止") }}');
            $('#btn_start').show();
            $('#btn_stop').hide();
            $('#btn_restart').hide();
            $('#btn_reload').hide();
        }
    }

    function updateStatus(force) {
        /* 5 秒轮询仅服务概览 Tab；页面隐藏或离开概览时跳过请求 */
        if (force !== true && (!isOverviewActive() || document.hidden)) {
            return;
        }
        ajaxGet('/api/mihomo/service/status', {}, function (data) {
            var running = (data && data.status === 'running');
            var $badge = $('#service_status_badge');
            if (running) {
                $badge.removeClass('label-default label-danger').addClass('label-success').empty()
                    .append($('<i class="fa fa-check-circle"></i>'))
                    .append(' ' + '{{ lang._("运行中") }}');
            } else {
                $badge.removeClass('label-default label-success').addClass('label-danger').empty()
                    .append($('<i class="fa fa-times-circle"></i>'))
                    .append(' ' + '{{ lang._("已停止") }}');
            }
            renderOverviewState(running);
        });
    }

    /* ---------- 剪贴板 ---------- */

    var currentApiBind = '';
    var currentApiPort = '';

    function copyToClipboard(text, successMsg) {
        if (!text || text === '-') {
            return;
        }
        if (navigator.clipboard && window.isSecureContext) {
            navigator.clipboard.writeText(text).then(function () {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_INFO,
                    title: '{{ lang._("复制成功") }}',
                    message: textBlock(successMsg || '{{ lang._("内容已复制到剪贴板。") }}')
                });
            }, function () {
                fallbackCopy(text, successMsg);
            });
        } else {
            fallbackCopy(text, successMsg);
        }
    }

    function fallbackCopy(text, successMsg) {
        var $temp = $('<textarea style="position: absolute; left: -9999px; top: -9999px;"></textarea>');
        $temp.val(text).appendTo('body');
        $temp.select();
        try {
            document.execCommand('copy');
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_INFO,
                title: '{{ lang._("复制成功") }}',
                message: textBlock(successMsg || '{{ lang._("内容已复制到剪贴板。") }}')
            });
        } catch (e) {
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_WARNING,
                title: '{{ lang._("复制失败") }}',
                message: textBlock('{{ lang._("请手动复制：") }}' + text)
            });
        }
        $temp.remove();
    }

    function updateApiDisplay(bind, port) {
        currentApiBind = (bind && String(bind).trim().length > 0) ? String(bind).trim() : '';
        currentApiPort = (port && String(port).trim().length > 0) ? String(port).trim() : '';

        if (!currentApiPort) {
            $('#api_header_port').text('');
            $('.api_disp_port').text('-');
            $('.api_disp_host').text('-');
            $('#api_endpoint_display').text('-');
            $('#api_bind_badge').text('-');
            $('#api_bundled_link').attr('href', '#').text('-').css('pointer-events', 'none').css('text-decoration', 'none');
            $('.api_link_preview').attr('href', '#').css('pointer-events', 'none').css('text-decoration', 'none');
            $('#btn_copy_api_endpoint').prop('disabled', true);
            $('#api_wan_warn').hide();
            return;
        }

        var dispHost = (currentApiBind === '0.0.0.0') ? window.location.hostname : (currentApiBind || window.location.hostname);
        var endpointUrl = 'http://' + dispHost + ':' + currentApiPort;
        var bundledUrl = endpointUrl + '/ui/';

        $('#api_header_port').text('{{ lang._("端口") }} ' + currentApiPort);
        $('.api_disp_host').text(dispHost);
        $('.api_disp_port').text(currentApiPort);
        $('#api_endpoint_display').text(endpointUrl);
        $('#api_bind_badge').text((currentApiBind || '-') + ':' + currentApiPort);

        $('#api_bundled_link')
            .attr('href', bundledUrl)
            .text(bundledUrl)
            .css('pointer-events', 'auto')
            .css('text-decoration', 'underline');

        $('.api_link_preview')
            .attr('href', bundledUrl)
            .css('pointer-events', 'auto')
            .css('text-decoration', 'underline');

        $('#btn_copy_api_endpoint').prop('disabled', false);

        if (currentApiBind === '0.0.0.0') {
            $('#api_wan_warn').show();
        } else {
            $('#api_wan_warn').hide();
        }
    }

    $('#btn_copy_api_endpoint').click(function () {
        var endpoint = $('#api_endpoint_display').text();
        if (endpoint && endpoint !== '-') {
            copyToClipboard(endpoint, '{{ lang._("API 端点地址已复制到剪贴板。") }}');
        }
    });

    function loadSecretMasked() {
        ajaxGet('/api/mihomo/general/getGeneral', {}, function (data) {
            var gen = (data && data.mihomo && data.mihomo.general) ? data.mihomo.general : ((data && data.general) ? data.general : {});
            var masked = gen.secret_masked || '';
            $('#api_secret_masked').text(masked || '{{ lang._("未配置") }}');
            var bind = gen.api_bind;
            var port = gen.api_port;
            updateApiDisplay(bind, port);
            /* 概览：接入方式 + 自启徽章（配置意图，实时态见运行状态页） */
            /* OptionField 在 JSON 中是 {key:{value,selected}} 字典，取 selected===1 的键 */
            var tm = '';
            if (gen.transport_mode && typeof gen.transport_mode === 'object') {
                $.each(gen.transport_mode, function (k, v) {
                    if (v && (v.selected === 1 || v.selected === true || v.selected === '1')) {
                        tm = String(k);
                        return false;
                    }
                });
            } else {
                tm = String(gen.transport_mode || '');
            }
            $('#ov_transport').text(tm === 'transparent' ? '{{ lang._("透明代理") }}' : (tm === 'proxy' ? '{{ lang._("仅代理") }}' : '-'));
            $('#ov_autostart').text(flagEnabled(gen.enabled) === '1' ? '{{ lang._("开") }}' : '{{ lang._("关") }}');
        });
    }

    function loadCoreMode() {
        ajaxGet('/api/mihomo/status/getMode', {}, function (data) {
            var names = {
                rule: '{{ lang._("规则分流") }}',
                global: '{{ lang._("全局代理") }}',
                direct: '{{ lang._("直连") }}'
            };
            var txt = '-';
            if (data && data.reachable && data.mode && names[data.mode]) {
                txt = names[data.mode];
            }
            $('#ov_core_mode').text(txt);
        });
    }

    function showSecretDialog(title, secret) {
        var $input = $('<input type="text" class="form-control" readonly style="font-family: Menlo, Monaco, Consolas, monospace;"/>').val(secret);
        var $wrap = $('<div></div>');
        var dispHost = (currentApiBind === '0.0.0.0') ? window.location.hostname : (currentApiBind || '-');
        var endpointText = currentApiPort ? (dispHost + ':' + currentApiPort) : '-';
        $('<p></p>').text('{{ lang._("使用此密钥登录 Web 控制台 / Metacubexd（地址 ") }}' + endpointText + '）：').appendTo($wrap);
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
        updateStatus(true);
    });

    /* ---------- 服务控制 ---------- */

    function callServiceAction(action) {
        ajaxCall('/api/mihomo/service/' + action, {}, function (data) {
            if (data && data.status === 'ok') {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_SUCCESS,
                    title: '{{ lang._("服务控制") }}',
                    message: textBlock(data.response || '{{ lang._("操作执行成功。") }}')
                });
            } else {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: textBlock((data && data.message) ? data.message : '{{ lang._("操作失败。") }}')
                });
            }
            setTimeout(function () { updateStatus(true); }, 1000);
        });
    }

    $('#btn_start').click(function() { callServiceAction('start'); });
    $('#btn_stop').click(function() {
        BootstrapDialog.confirm({
            title: '{{ lang._("确认停止服务") }}',
            message: '{{ lang._("停止 Mihomo 将中断透明代理分流并恢复直连，确定停止？") }}',
            type: BootstrapDialog.TYPE_DANGER,
            btnCancelLabel: '{{ lang._("取消") }}',
            btnOKLabel: '{{ lang._("确认停止") }}',
            btnOKClass: 'btn-danger',
            callback: function (confirmed) {
                if (confirmed) {
                    callServiceAction('stop');
                }
            }
        });
    });
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
            updateStatus(true);
            var failed = (data && data.status === 'failed');
            var $message = messageLines(failed ? [] : (data ? data.messages : []));
            var flat = '';
            if ($message.children().length === 0) {
                if (failed) {
                    $message.text(data && data.message ? data.message : '{{ lang._("保存设置失败。") }}');
                } else {
                    $message.text('{{ lang._("设置已保存。") }}');
                }
            }
            if (failed) {
                BootstrapDialog.show({
                    type: BootstrapDialog.TYPE_DANGER,
                    title: '{{ lang._("错误") }}',
                    message: $message
                });
            } else {
                $message.children().each(function () { flat += $(this).text() + ' '; });
                showSaveToast($.trim(flat) || '{{ lang._("设置已保存。") }}');
            }
            loadSecretMasked();
        }, true, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            updateStatus(true);
            BootstrapDialog.show({
                type: BootstrapDialog.TYPE_DANGER,
                title: '{{ lang._("错误") }}',
                message: textBlock(data && data.message ? data.message : '{{ lang._("保存设置失败。") }}')
            });
        });
    });

    /* ---------- 订阅与策略 ---------- */

    function setSubUpdating(active) {
        subUpdateInProgress = active;
        $('#btn_sub_update, #ov_btn_sub_update').prop('disabled', active);
        $('#btn_sub_update_icon').removeClass('fa-cloud-download fa-spinner fa-pulse');
        $('#btn_sub_update_icon').addClass(active ? 'fa-spinner fa-pulse' : 'fa-cloud-download');
    }

    function flagEnabled(value) {
        return (value === true || value === 1 || value === '1' || value === 'true') ? '1' : '0';
    }

    function relativeTime(iso) {
        if (!iso) {
            return '-';
        }
        var t = new Date(String(iso));
        var ms = t.getTime();
        if (isNaN(ms)) {
            return String(iso);
        }
        var diff = (new Date()).getTime() - ms;
        if (diff < 0) {
            diff = 0;
        }
        var min = Math.floor(diff / 60000);
        if (min < 1) {
            return '{{ lang._("刚刚") }}';
        }
        if (min < 60) {
            return min + ' {{ lang._("分钟前") }}';
        }
        var h = Math.floor(min / 60);
        if (h < 24) {
            return h + ' {{ lang._("小时前") }}';
        }
        return Math.floor(h / 24) + ' {{ lang._("天前") }}';
    }

    function renderLastUpdate(lastUpdate) {
        var $badge = $('#sub_state_result');
        var $ovBadge = $('#ov_sub_result');
        $badge.removeClass('label-default label-success label-danger label-warning');
        $ovBadge.removeClass('label-default label-success label-danger label-warning');
        if (!lastUpdate || typeof lastUpdate !== 'object') {
            subLastUpdateTime = null;
            $('#sub_state_time').text('-');
            $('#sub_state_nodes').text('-');
            $('#sub_state_strategy').text('-');
            $('#sub_state_groups').text('-');
            $('#sub_state_rules').text('-');
            $('#sub_state_message').text('-');
            $badge.addClass('label-default').text('-');
            $('#ov_nodes').text('-');
            $('#ov_groups').text('-');
            $('#ov_rules').text('-');
            $('#ov_sub_masked').text('-');
            $('#ov_sub_result').addClass('label-default').text('-');
            $('#ov_sub_time').text('-');
            $('#ov_sub_msg').hide();
            return;
        }
        subLastUpdateTime = lastUpdate.time ? String(lastUpdate.time) : null;
        $('#sub_state_time').text(lastUpdate.time ? String(lastUpdate.time) : '-');
        $('#sub_state_nodes').text((lastUpdate.nodes !== undefined && lastUpdate.nodes !== null) ? String(lastUpdate.nodes) : '-');
        $('#sub_state_strategy').text(lastUpdate.strategy === 'subscription' ? '{{ lang._("订阅自带") }}' : '{{ lang._("插件模板") }}');
        $('#sub_state_groups').text((lastUpdate.groups !== undefined && lastUpdate.groups !== null && lastUpdate.groups !== '') ? String(lastUpdate.groups) : '-');
        $('#sub_state_rules').text((lastUpdate.rules !== undefined && lastUpdate.rules !== null && lastUpdate.rules !== '') ? String(lastUpdate.rules) : '-');
        $('#sub_state_message').text(lastUpdate.message ? String(lastUpdate.message) : '-');
        var result = (lastUpdate.result ? String(lastUpdate.result) : '').toLowerCase();
        var resultText = '-';
        var resultClass = 'label-default';
        if (result === 'success') {
            resultClass = 'label-success';
            resultText = '{{ lang._("成功") }}';
        } else if (result === 'failed') {
            resultClass = 'label-danger';
            resultText = '{{ lang._("失败") }}';
        } else if (result.length > 0) {
            resultClass = 'label-warning';
            resultText = result;
        }
        $badge.addClass(resultClass).text(resultText);
        $ovBadge.addClass(resultClass).text(resultText);
        /* 概览数字（骨架占位在此被 .text() 替换；千分位仅用于展示） */
        function fmtNum(v) {
            if (v === undefined || v === null || v === '') {
                return '-';
            }
            return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ',');
        }
        $('#ov_nodes').text(fmtNum(lastUpdate.nodes));
        $('#ov_groups').text(fmtNum(lastUpdate.groups));
        $('#ov_rules').text(fmtNum(lastUpdate.rules));
        $('#ov_sub_time').text(relativeTime(lastUpdate.time));
        var msg = lastUpdate.message ? String(lastUpdate.message) : '';
        if (msg.length > 0) {
            $('#ov_sub_msg').text(msg.length > 60 ? msg.slice(0, 60) + '...' : msg).show();
        } else {
            $('#ov_sub_msg').hide();
        }
    }

    function syncStrategyCards() {
        var v = $('#sub_strategy').val() || 'subscription';
        $('#sub_strategy_cards .mihomo-radio-card').each(function () {
            $(this).toggleClass('is-active', $(this).attr('data-val') === v);
        });
    }

    $('#sub_strategy_cards').on('click', '.mihomo-radio-card', function () {
        $('#sub_strategy').val($(this).attr('data-val'));
        syncStrategyCards();
    });

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
        syncStrategyCards();
    }

    function loadSubscription(applyForm) {
        ajaxGet('/api/mihomo/subscription/get', {}, function (data) {
            if (!data || data.status !== 'ok') {
                /* 接口异常时落地骨架屏，避免占位扫光常驻 */
                renderLastUpdate(null);
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

    function triggerSubUpdate() {
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
    }

    $('#btn_sub_update').click(triggerSubUpdate);
    $('#ov_btn_sub_update').click(triggerSubUpdate);

    /* ---------- 面板与 API ---------- */

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
        BootstrapDialog.confirm({
            title: '{{ lang._("确认生成新密钥") }}',
            message: '{{ lang._("生成新密钥并热重载 Mihomo？旧密钥将立即失效。") }}',
            type: BootstrapDialog.TYPE_WARNING,
            btnCancelLabel: '{{ lang._("取消") }}',
            btnOKLabel: '{{ lang._("生成新密钥") }}',
            btnOKClass: 'btn-warning',
            callback: function (confirmed) {
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
        });
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

    /* ---------- 初始化 ---------- */

    loadSubscription(true);
    loadSecretMasked();
    loadCoreMode();
    syncStrategyCards();
    updateStatus(true);
    setInterval(updateStatus, 5000);
});
</script>
