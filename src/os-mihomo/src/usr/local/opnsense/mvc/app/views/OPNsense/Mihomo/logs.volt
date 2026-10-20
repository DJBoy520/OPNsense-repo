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

    <!-- 顶部控件栏 -->
    <div class="col-xs-12 form-inline" style="margin-bottom: 12px; display: flex; flex-wrap: wrap; align-items: center; gap: 10px;">
        <div class="form-group">
            <label for="log_level_filter" style="margin-right: 6px;">{{ lang._('Log Level Filter:') }}</label>
            <select id="log_level_filter" class="selectpicker" data-width="130px">
                <option value="all" selected>{{ lang._('All Levels') }}</option>
                <option value="debug">Debug</option>
                <option value="info">Info</option>
                <option value="warning">Warning</option>
                <option value="error">Error</option>
            </select>
        </div>

        <div class="form-group">
            <label for="log_limit" style="margin-right: 6px;">{{ lang._('Lines:') }}</label>
            <select id="log_limit" class="selectpicker" data-width="90px">
                <option value="100">100</option>
                <option value="200" selected>200</option>
                <option value="500">500</option>
                <option value="1000">1000</option>
                <option value="2000">2000</option>
            </select>
        </div>

        <div class="form-group">
            <button class="btn btn-default" id="btn_toggle_pause" type="button" title="{{ lang._('Pause/Resume polling') }}">
                <i class="fa fa-pause" id="icon_toggle_pause"></i> <span id="text_toggle_pause">{{ lang._('Pause') }}</span>
            </button>
            <button class="btn btn-default" id="btn_clear_logs" type="button" title="{{ lang._('Clear screen') }}">
                <i class="fa fa-trash-o"></i> {{ lang._('Clear') }}
            </button>
            <button class="btn btn-default" id="btn_download_logs" type="button" title="{{ lang._('Download raw logs') }}">
                <i class="fa fa-download"></i> {{ lang._('Download') }}
            </button>
        </div>

        <div class="form-group">
            <label style="font-weight: normal; margin-bottom: 0; cursor: pointer;">
                <input type="checkbox" id="chk_auto_scroll" checked> {{ lang._('Auto Scroll') }}
            </label>
        </div>

        <!-- 状态指示徽章 -->
        <div class="form-group" style="margin-left: auto;">
            <span id="log_conn_status" class="label label-success" style="font-size: 12px; padding: 5px 10px;">
                <i class="fa fa-circle" style="font-size: 9px; vertical-align: middle; margin-right: 4px;"></i><span id="log_conn_text">{{ lang._('Live') }}</span>
            </span>
        </div>
    </div>

    <!-- 表格化滚动区 -->
    <div class="col-xs-12">
        <div id="log_container" style="height: 600px; overflow-y: auto; overflow-x: hidden; background-color: #1e1e1e; border: 1px solid #444; border-radius: 4px; padding: 0;">
            <table class="table table-condensed" style="margin-bottom: 0; width: 100%; border-collapse: collapse; font-family: Menlo, Monaco, Consolas, 'Courier New', monospace; font-size: 12px;">
                <thead>
                    <tr style="background-color: #2d2d2d; color: #aaa; border-bottom: 2px solid #444; position: sticky; top: 0; z-index: 2;">
                        <th style="width: 175px; min-width: 175px; padding: 6px 10px; border: none;">{{ lang._('Time') }}</th>
                        <th style="width: 80px; min-width: 80px; padding: 6px 8px; border: none; text-align: center;">{{ lang._('Level') }}</th>
                        <th style="padding: 6px 10px; border: none;">{{ lang._('Message') }}</th>
                    </tr>
                </thead>
                <tbody id="log_table_body">
                    <!-- 日志动态插入 -->
                </tbody>
            </table>
        </div>
    </div>
</div>

<script>
$(function () {
    $('.selectpicker').selectpicker('refresh');

    var currentCursor = 0;
    var isPaused = false;
    var pollTimer = null;
    var retryDelay = 2000;
    var MAX_DOM_ROWS = 2000;

    var $tableBody = $('#log_table_body');
    var $container = $('#log_container');
    var $btnPause = $('#btn_toggle_pause');
    var $iconPause = $('#icon_toggle_pause');
    var $textPause = $('#text_toggle_pause');
    var $btnClear = $('#btn_clear_logs');
    var $btnDownload = $('#btn_download_logs');
    var $chkAutoScroll = $('#chk_auto_scroll');
    var $connStatus = $('#log_conn_status');
    var $connText = $('#log_conn_text');

    function updateConnStatus(state, extra) {
        if (state === 'live') {
            $connStatus.removeClass('label-warning label-danger label-default').addClass('label-success');
            $connText.text('{{ lang._("Live") }}');
        } else if (state === 'paused') {
            $connStatus.removeClass('label-success label-danger label-warning').addClass('label-default');
            $connText.text('{{ lang._("Paused") }}');
        } else if (state === 'error') {
            $connStatus.removeClass('label-success label-default label-warning').addClass('label-danger');
            $connText.text(extra || '{{ lang._("Read Error") }}');
        } else if (state === 'reconnecting') {
            $connStatus.removeClass('label-success label-default label-danger').addClass('label-warning');
            var delaySec = Math.round(extra / 1000);
            $connText.text('{{ lang._("Reconnecting") }} (' + delaySec + 's)');
        }
    }

    function formatTime(isoStr) {
        if (!isoStr) {
            return '';
        }
        var d = new Date(isoStr);
        if (isNaN(d.getTime())) {
            return isoStr;
        }
        var year = d.getFullYear();
        var month = String(d.getMonth() + 1).padStart(2, '0');
        var day = String(d.getDate()).padStart(2, '0');
        var hours = String(d.getHours()).padStart(2, '0');
        var minutes = String(d.getMinutes()).padStart(2, '0');
        var seconds = String(d.getSeconds()).padStart(2, '0');
        var ms = String(d.getMilliseconds()).padStart(3, '0');
        return year + '-' + month + '-' + day + ' ' + hours + ':' + minutes + ':' + seconds + '.' + ms;
    }

    function createBadge(level) {
        var $badge = $('<span></span>').addClass('label');
        var lvl = (level || '').toLowerCase();
        $badge.text(lvl.toUpperCase());

        if (lvl === 'debug') {
            $badge.addClass('label-default').css({
                'background-color': '#555',
                'color': '#eee',
                'font-size': '10px',
                'padding': '2px 6px'
            });
        } else if (lvl === 'info') {
            $badge.addClass('label-info').css({
                'background-color': '#337ab7',
                'color': '#fff',
                'font-size': '10px',
                'padding': '2px 6px'
            });
        } else if (lvl === 'warning' || lvl === 'warn') {
            $badge.addClass('label-warning').css({
                'background-color': '#f0ad4e',
                'color': '#fff',
                'font-size': '10px',
                'padding': '2px 6px'
            });
        } else if (lvl === 'error' || lvl === 'fatal') {
            $badge.addClass('label-danger').css({
                'background-color': '#d9534f',
                'color': '#fff',
                'font-size': '10px',
                'padding': '2px 6px'
            });
        } else {
            $badge.addClass('label-default').css({
                'background-color': '#777',
                'color': '#eee',
                'font-size': '10px',
                'padding': '2px 6px'
            });
        }
        return $badge;
    }

    function appendEntry(entry) {
        var $tr = $('<tr></tr>').css({
            'border-bottom': '1px solid #2e2e2e',
            'color': '#dcdcdc'
        });

        if (entry.raw !== undefined) {
            // 解析失败整行放 raw 字段
            var $tdRaw = $('<td></td>')
                .attr('colspan', '3')
                .css({
                    'padding': '4px 10px',
                    'white-space': 'pre-wrap',
                    'word-break': 'break-all',
                    'color': '#bbb'
                })
                .text(entry.raw);
            $tr.append($tdRaw);
        } else {
            // 结构化条目: time, level, msg
            var $tdTime = $('<td></td>')
                .css({
                    'padding': '4px 10px',
                    'white-space': 'nowrap',
                    'color': '#888',
                    'vertical-align': 'top'
                })
                .text(formatTime(entry.time));

            var $tdLevel = $('<td></td>')
                .css({
                    'padding': '4px 8px',
                    'text-align': 'center',
                    'vertical-align': 'top'
                })
                .append(createBadge(entry.level));

            var $tdMsg = $('<td></td>')
                .css({
                    'padding': '4px 10px',
                    'white-space': 'pre-wrap',
                    'word-break': 'break-all',
                    'vertical-align': 'top'
                })
                .text(entry.msg);

            $tr.append($tdTime).append($tdLevel).append($tdMsg);
        }

        $tableBody.append($tr);
    }

    function trimDomRows() {
        var rowCount = $tableBody.children('tr').length;
        if (rowCount > MAX_DOM_ROWS) {
            var excess = rowCount - MAX_DOM_ROWS;
            $tableBody.children('tr').slice(0, excess).remove();
        }
    }

    function scrollToBottom() {
        if ($chkAutoScroll.is(':checked')) {
            $container.scrollTop($container[0].scrollHeight);
        }
    }

    function schedulePoll(delay) {
        clearTimeout(pollTimer);
        if (!isPaused) {
            pollTimer = setTimeout(pollLogs, delay);
        }
    }

    function pollLogs() {
        if (isPaused) {
            return;
        }

        var level = $('#log_level_filter').val();
        var limit = parseInt($('#log_limit').val(), 10) || 200;

        ajaxCall('/api/mihomo/logs/getLogs', {
            level: level,
            limit: limit,
            cursor: currentCursor
        }, function (data, status) {
            if (isPaused) {
                return;
            }

            if (data && data.status === 'ok') {
                retryDelay = 2000;
                updateConnStatus('live');

                if (data.truncated) {
                    $tableBody.empty();
                }

                if (Array.isArray(data.entries) && data.entries.length > 0) {
                    for (var i = 0; i < data.entries.length; i++) {
                        appendEntry(data.entries[i]);
                    }
                    trimDomRows();
                    scrollToBottom();
                }

                if (data.cursor !== undefined) {
                    currentCursor = parseInt(data.cursor, 10);
                }

                schedulePoll(2000);
            } else if (data && data.status === 'failed') {
                // 服务端明确返回读取失败（如无权限读取日志）
                updateConnStatus('error', data.message || '{{ lang._("Read Error") }}');
                handlePollFailure();
            } else {
                handlePollFailure();
            }
        });
    }

    function handlePollFailure() {
        if (isPaused) {
            return;
        }
        if ($connStatus.hasClass('label-danger')) {
            // 已显示错误状态，仅更新定时重试，不覆盖状态文本
        } else {
            updateConnStatus('reconnecting', retryDelay);
        }
        schedulePoll(retryDelay);
        retryDelay = Math.min(retryDelay * 2, 10000);
    }

    // 暂停/恢复切换
    $btnPause.click(function () {
        if (isPaused) {
            isPaused = false;
            $iconPause.removeClass('fa-play').addClass('fa-pause');
            $textPause.text('{{ lang._("Pause") }}');
            updateConnStatus('live');
            retryDelay = 2000;
            pollLogs();
        } else {
            isPaused = true;
            clearTimeout(pollTimer);
            $iconPause.removeClass('fa-pause').addClass('fa-play');
            $textPause.text('{{ lang._("Resume") }}');
            updateConnStatus('paused');
        }
    });

    // 清屏
    $btnClear.click(function () {
        $tableBody.empty();
    });

    // 原始日志下载（前端 Blob 下载）
    $btnDownload.click(function () {
        var lines = [];
        $tableBody.find('tr').each(function () {
            var $row = $(this);
            var $tds = $row.children('td');
            if ($tds.length === 1) {
                lines.push($tds.text());
            } else if ($tds.length === 3) {
                var t = $($tds[0]).text();
                var l = $($tds[1]).text().trim();
                var m = $($tds[2]).text();
                lines.push('[' + t + '] [' + l + '] ' + m);
            }
        });

        var blob = new Blob([lines.join('\r\n')], { type: 'text/plain;charset=utf-8' });
        var url = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = url;
        a.download = 'mihomo-' + new Date().toISOString().replace(/[:.]/g, '-') + '.log';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    });

    // 过滤条件改变：重置游标并重新拉取
    $('#log_level_filter, #log_limit').change(function () {
        currentCursor = 0;
        $tableBody.empty();
        if (!isPaused) {
            clearTimeout(pollTimer);
            pollLogs();
        }
    });

    // 初次加载
    pollLogs();
});
</script>
