{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}

<div class="content-box" style="padding-bottom: 1.5em;">
    <div class="col-xs-12">
        <h2>{{ lang._('Mihomo - Custom Rules') }}</h2>
        <p class="text-muted">{{ lang._('Persistent rules injected at the top of the generated rule list. Custom rules survive subscription updates.') }}</p>
        <hr/>
    </div>

    <div class="col-xs-12">
        <p>
            <strong>{{ lang._('Allowed Rule Types:') }}</strong>
            <span id="rules_types_container">
                <code>DOMAIN</code>, <code>DOMAIN-SUFFIX</code>, <code>DOMAIN-KEYWORD</code>,
                <code>IP-CIDR</code>, <code>IP-CIDR6</code>, <code>GEOIP</code>, <code>GEOSITE</code>,
                <code>DST-PORT</code>
            </span>
        </p>
        <div class="form-group">
            <label>{{ lang._('Allowed Targets') }}</label>
            <div id="rules_targets">
                <span class="text-muted"><i class="fa fa-spinner fa-spin"></i> {{ lang._('Loading...') }}</span>
            </div>
            <span class="help-block">{{ lang._('Only the targets listed above may be used as the destination of a rule.') }}</span>
        </div>
    </div>

    <!-- 表格编辑器与源码模式容器 -->
    <div class="col-xs-12">
        <div class="form-group">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                <label style="margin-bottom: 0;">{{ lang._('Custom Rules Editor') }}</label>
                <div class="btn-group">
                    <button class="btn btn-default btn-xs active" id="btn_mode_table" type="button">
                        <i class="fa fa-table"></i> {{ lang._('Table Mode') }}
                    </button>
                    <button class="btn btn-default btn-xs" id="btn_mode_raw" type="button">
                        <i class="fa fa-code"></i> {{ lang._('Raw Source Mode') }}
                    </button>
                </div>
            </div>

            <!-- 文件级全局错误展示区 (line=0) -->
            <div id="rules_file_error" class="alert alert-danger" style="display: none; margin-bottom: 10px;"></div>

            <!-- 1. 表格编辑器视图 -->
            <div id="rules_table_view">
                <div class="table-responsive">
                    <table class="table table-striped table-bordered table-condensed" id="tbl_rules_editor">
                        <thead>
                            <tr>
                                <th style="width: 50px; text-align: center;">#</th>
                                <th style="width: 200px;">{{ lang._('Type') }}</th>
                                <th>{{ lang._('Payload / Value') }}</th>
                                <th style="width: 220px;">{{ lang._('Target / Policy') }}</th>
                                <th style="width: 140px;">{{ lang._('Options') }}</th>
                                <th style="width: 70px; text-align: center;">{{ lang._('Action') }}</th>
                            </tr>
                        </thead>
                        <tbody id="tbl_rules_body">
                            <!-- 动态行 -->
                        </tbody>
                    </table>
                </div>
                <div style="margin-top: 5px;">
                    <button class="btn btn-default btn-sm" id="btn_add_rule_row" type="button">
                        <i class="fa fa-plus"></i> {{ lang._('Add Rule') }}
                    </button>
                </div>
            </div>

            <!-- 2. 源码文本模式视图 -->
            <div id="rules_raw_view" style="display: none;">
                <textarea id="rules_content" class="form-control" rows="16" spellcheck="false" style="font-family: Menlo, Monaco, Consolas, 'Courier New', monospace; font-size: 13px; line-height: 1.4; height: 320px; resize: vertical;"></textarea>
                <span class="help-block">{{ lang._('One rule per line, for example: DOMAIN-SUFFIX,example.com,DIRECT. Lines starting with # are ignored.') }}</span>
            </div>

            <span class="help-block" id="rules_counter" style="margin-top: 8px;">{{ lang._('Lines') }}: 0 / 200 | {{ lang._('Bytes') }}: 0 / 32768</span>
        </div>
    </div>

    <div class="col-xs-12">
        <button class="btn btn-primary" id="btn_rules_apply" type="button">
            <b>{{ lang._('Validate & Apply') }}</b> <i id="btn_rules_apply_progress"></i>
        </button>
    </div>

    <div class="col-xs-12" style="margin-top: 15px;">
        <div id="rules_result" class="alert" style="display: none;"></div>
        <table id="rules_error_table" class="table table-condensed table-bordered" style="display: none;">
            <thead>
                <tr>
                    <th style="width: 100px;">{{ lang._('Line') }}</th>
                    <th>{{ lang._('Message') }}</th>
                </tr>
            </thead>
            <tbody id="rules_error_body"></tbody>
        </table>
    </div>
</div>

<!-- 当前生效规则只读视图 -->
<div class="content-box" style="padding-bottom: 1.5em; margin-top: 20px;">
    <div class="col-xs-12">
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <div>
                <h3 style="margin-top: 10px;">{{ lang._('Effective Rules (Runtime)') }}</h3>
                <p class="text-muted">{{ lang._('Real-time routing rules currently running in Mihomo core. Custom rules matching payloads are highlighted.') }}</p>
            </div>
            <div>
                <button class="btn btn-default" id="btn_refresh_effective" type="button">
                    <i class="fa fa-refresh"></i> {{ lang._('Refresh') }} <i id="effective_refresh_spinner"></i>
                </button>
            </div>
        </div>
        <hr style="margin-top: 5px;"/>
    </div>

    <div class="col-xs-12" style="margin-bottom: 12px;">
        <div class="input-group" style="max-width: 400px;">
            <input type="text" id="filter_effective_rules" class="form-control" placeholder="{{ lang._('Search rule type, payload, or proxy...') }}">
            <span class="input-group-addon"><i class="fa fa-search"></i></span>
        </div>
    </div>

    <div class="col-xs-12">
        <div id="effective_rules_alert" class="alert alert-warning" style="display: none;"></div>
        <div class="table-responsive" style="max-height: 480px; overflow-y: auto;">
            <table class="table table-striped table-bordered table-condensed" id="tbl_effective_rules">
                <thead>
                    <tr>
                        <th style="width: 50px; text-align: center;">#</th>
                        <th style="width: 180px;">{{ lang._('Type') }}</th>
                        <th>{{ lang._('Payload') }}</th>
                        <th style="width: 220px;">{{ lang._('Proxy / Target') }}</th>
                        <th style="width: 100px; text-align: center;">{{ lang._('Source') }}</th>
                    </tr>
                </thead>
                <tbody id="tbl_effective_body">
                    <tr>
                        <td colspan="5" class="text-center text-muted" id="tbl_effective_empty">
                            <i class="fa fa-spinner fa-spin"></i> {{ lang._('Loading effective rules...') }}
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
        <div class="text-muted" style="margin-top: 5px; font-size: 12px;" id="effective_count_label">
            {{ lang._('Total rules') }}: 0
        </div>
    </div>
</div>

<script>
$(function () {
    var rulesLimits = {
        maxLines: 200,
        maxBytes: 32768
    };

    var allowedRuleTypes = [
        'DOMAIN',
        'DOMAIN-SUFFIX',
        'DOMAIN-KEYWORD',
        'IP-CIDR',
        'IP-CIDR6',
        'GEOIP',
        'GEOSITE',
        'DST-PORT'
    ];

    var allowedTargets = ['DIRECT', 'REJECT', 'REJECT-DROP'];
    var currentMode = 'table'; // 'table' or 'raw'
    var effectiveRulesCache = [];

    function utf8Bytes(text) {
        if (typeof Blob === 'function') {
            try {
                return (new Blob([text])).size;
            } catch (e) {
                /* Blob 不可用时回落到下面的编码估算 */
            }
        }
        return encodeURIComponent(text).replace(/%[0-9A-F]{2}/gi, 'x').length;
    }

    function countRuleLines(text) {
        var count = 0;
        $.each(String(text).split(/\r?\n/), function (i, line) {
            if ($.trim(line).length > 0) {
                count += 1;
            }
        });
        return count;
    }

    function updateCounter() {
        var text = (currentMode === 'table') ? serializeTableToText() : ($('#rules_content').val() || '');
        var bytes = utf8Bytes(text);
        var lines = countRuleLines(text);
        var $counter = $('#rules_counter');
        $counter.removeClass('text-danger');
        $counter.text('{{ lang._("Lines") }}: ' + lines + ' / ' + rulesLimits.maxLines + ' | ' +
                      '{{ lang._("Bytes") }}: ' + bytes + ' / ' + rulesLimits.maxBytes);
        if (bytes > rulesLimits.maxBytes || lines > rulesLimits.maxLines) {
            $counter.addClass('text-danger');
            if (lines > rulesLimits.maxLines) {
                $counter.append(' - ' + '{{ lang._("Exceeds the maximum number of lines.") }}');
            }
            if (bytes > rulesLimits.maxBytes) {
                $counter.append(' - ' + '{{ lang._("Exceeds the maximum rule size.") }}');
            }
        }
    }

    function renderTargets(targets) {
        if (Array.isArray(targets) && targets.length > 0) {
            allowedTargets = targets;
        }
        var $box = $('#rules_targets');
        $box.empty();
        if (!Array.isArray(allowedTargets) || allowedTargets.length === 0) {
            $box.append($('<span class="text-muted"></span>').text('{{ lang._("No targets reported.") }}'));
            return;
        }
        $.each(allowedTargets, function (i, target) {
            if (i > 0) {
                $box.append(document.createTextNode(', '));
            }
            $('<span class="label label-info"></span>')
                .css({'display': 'inline-block', 'margin': '0 2px 2px 0', 'padding': '4px 7px'})
                .text(String(target))
                .appendTo($box);
        });
    }

    function renderRuleTypes(types) {
        if (Array.isArray(types) && types.length > 0) {
            allowedRuleTypes = types;
            var $container = $('#rules_types_container');
            $container.empty();
            $.each(allowedRuleTypes, function (i, t) {
                if (i > 0) {
                    $container.append(document.createTextNode(', '));
                }
                $('<code></code>').text(String(t)).appendTo($container);
            });
        }
    }

    function buildTypeSelect(selectedType) {
        var $select = $('<select class="form-control input-sm rule-field-type"></select>');
        var found = false;
        $.each(allowedRuleTypes, function (i, t) {
            var $opt = $('<option></option>').attr('value', t).text(t);
            if (t === selectedType) {
                $opt.prop('selected', true);
                found = true;
            }
            $select.append($opt);
        });
        if (!found && selectedType) {
            var $customOpt = $('<option></option>').attr('value', selectedType).text(selectedType).prop('selected', true);
            $select.prepend($customOpt);
        }
        return $select;
    }

    function buildTargetSelect(selectedTarget) {
        var $select = $('<select class="form-control input-sm rule-field-target"></select>');
        var found = false;
        $.each(allowedTargets, function (i, tgt) {
            var $opt = $('<option></option>').attr('value', tgt).text(tgt);
            if (tgt === selectedTarget) {
                $opt.prop('selected', true);
                found = true;
            }
            $select.append($opt);
        });
        if (!found && selectedTarget) {
            var $customOpt = $('<option></option>').attr('value', selectedTarget).text(selectedTarget).prop('selected', true);
            $select.prepend($customOpt);
        }
        return $select;
    }

    function createTableRow(type, payload, target, noResolve, lineNumber, commentText) {
        var $tr = $('<tr class="rule-row"></tr>');
        $tr.attr('data-line', lineNumber || '');

        // 序号列
        var $tdIndex = $('<td style="text-align: center; vertical-align: middle;" class="row-index"></td>');
        $tr.append($tdIndex);

        if (commentText !== undefined && commentText !== null) {
            // 注释行或无法结构化解析的行
            $tr.addClass('rule-comment-row');
            var $tdComment = $('<td colspan="4" style="vertical-align: middle;"></td>');
            var $input = $('<input type="text" class="form-control input-sm rule-raw-line" spellcheck="false" />');
            $input.val(commentText);
            $input.on('input', updateCounter);
            $tdComment.append($input);
            $tr.append($tdComment);
        } else {
            // 结构化规则行
            var $tdType = $('<td style="vertical-align: middle;"></td>');
            var $selType = buildTypeSelect(type);
            $selType.on('change', updateCounter);
            $tdType.append($selType);
            $tr.append($tdType);

            var $tdPayload = $('<td style="vertical-align: middle;"></td>');
            var $inPayload = $('<input type="text" class="form-control input-sm rule-field-payload" spellcheck="false" />');
            $inPayload.val(payload || '');
            $inPayload.on('input', updateCounter);
            $tdPayload.append($inPayload);
            var $inlineErr = $('<div class="text-danger rule-row-error" style="font-size: 11px; margin-top: 3px; display: none;"></div>');
            $tdPayload.append($inlineErr);
            $tr.append($tdPayload);

            var $tdTarget = $('<td style="vertical-align: middle;"></td>');
            var $selTarget = buildTargetSelect(target);
            $selTarget.on('change', updateCounter);
            $tdTarget.append($selTarget);
            $tr.append($tdTarget);

            var $tdOptions = $('<td style="vertical-align: middle;"></td>');
            var $chkLabel = $('<label style="font-weight: normal; margin-bottom: 0; cursor: pointer;"></label>');
            var $chkNoResolve = $('<input type="checkbox" class="rule-field-no-resolve" style="margin-right: 4px;" />');
            if (noResolve) {
                $chkNoResolve.prop('checked', true);
            }
            $chkNoResolve.on('change', updateCounter);
            $chkLabel.append($chkNoResolve).append(document.createTextNode('no-resolve'));
            $tdOptions.append($chkLabel);
            $tr.append($tdOptions);
        }

        // 操作列（删除按钮）
        var $tdAction = $('<td style="text-align: center; vertical-align: middle;"></td>');
        var $btnDel = $('<button class="btn btn-default btn-xs btn-del-row" type="button" title="{{ lang._("Delete rule") }}"><i class="fa fa-trash-o text-danger"></i></button>');
        $btnDel.on('click', function () {
            $tr.remove();
            reindexTableRows();
            updateCounter();
        });
        $tdAction.append($btnDel);
        $tr.append($tdAction);

        return $tr;
    }

    function reindexTableRows() {
        $('#tbl_rules_body tr').each(function (idx) {
            $(this).find('.row-index').text(idx + 1);
        });
    }

    function parseTextToTable(text) {
        var $body = $('#tbl_rules_body');
        $body.empty();
        var lines = String(text || '').split(/\r?\n/);

        $.each(lines, function (idx, rawLine) {
            var lineNo = idx + 1;
            var line = $.trim(rawLine);
            if (line === '') {
                return; // 跳过纯空行
            }
            if (line.charAt(0) === '#') {
                // 注释行保留原样
                var $row = createTableRow(null, null, null, false, lineNo, rawLine);
                $body.append($row);
                return;
            }

            var parts = line.split(',');
            if (parts.length === 3 || parts.length === 4) {
                var type = $.trim(parts[0]);
                var payload = $.trim(parts[1]);
                var target = $.trim(parts[2]);
                var noResolve = false;
                if (parts.length === 4 && $.trim(parts[3]) === 'no-resolve') {
                    noResolve = true;
                }
                var $row = createTableRow(type, payload, target, noResolve, lineNo);
                $body.append($row);
            } else {
                // 无法匹配 3 或 4 段的行，作为原生行保留
                var $row = createTableRow(null, null, null, false, lineNo, rawLine);
                $body.append($row);
            }
        });

        if ($body.children().length === 0) {
            // 空规则时添加一个空白行
            $body.append(createTableRow(allowedRuleTypes[0] || 'DOMAIN-SUFFIX', '', allowedTargets[0] || 'DIRECT', false, 1));
        }

        reindexTableRows();
    }

    function serializeTableToText() {
        var lines = [];
        var outLineNum = 1;
        $('#tbl_rules_body tr').each(function () {
            var $tr = $(this);
            if ($tr.hasClass('rule-comment-row')) {
                var rawVal = $tr.find('.rule-raw-line').val();
                if (rawVal !== undefined && rawVal !== null && $.trim(rawVal) !== '') {
                    lines.push(rawVal);
                    $tr.attr('data-line', outLineNum);
                    outLineNum++;
                } else {
                    $tr.removeAttr('data-line');
                }
            } else {
                var type = $tr.find('.rule-field-type').val() || '';
                var payload = $.trim($tr.find('.rule-field-payload').val() || '');
                var target = $tr.find('.rule-field-target').val() || '';
                var isNoResolve = $tr.find('.rule-field-no-resolve').is(':checked');

                // 只有当有 payload 时才组装输出（避免空行生成无效规则 DOMAIN,,DIRECT）
                if (payload !== '') {
                    var ruleStr = type + ',' + payload + ',' + target;
                    if (isNoResolve) {
                        ruleStr += ',no-resolve';
                    }
                    lines.push(ruleStr);
                    $tr.attr('data-line', outLineNum);
                    outLineNum++;
                } else {
                    $tr.removeAttr('data-line');
                }
            }
        });
        return lines.join('\n');
    }

    function getCustomPayloadsSet() {
        var text = (currentMode === 'table') ? serializeTableToText() : ($('#rules_content').val() || '');
        var set = {};
        var lines = text.split(/\r?\n/);
        $.each(lines, function (i, l) {
            var trimmed = $.trim(l);
            if (trimmed === '' || trimmed.charAt(0) === '#') {
                return;
            }
            var parts = trimmed.split(',');
            if (parts.length >= 2) {
                var p = $.trim(parts[1]);
                if (p) {
                    set[p] = true;
                }
            }
        });
        return set;
    }

    function switchMode(newMode) {
        if (currentMode === newMode) {
            return;
        }
        if (newMode === 'raw') {
            var text = serializeTableToText();
            $('#rules_content').val(text);
            $('#rules_table_view').hide();
            $('#rules_raw_view').show();
            $('#btn_mode_table').removeClass('active');
            $('#btn_mode_raw').addClass('active');
            currentMode = 'raw';
        } else {
            var text = $('#rules_content').val() || '';
            parseTextToTable(text);
            $('#rules_raw_view').hide();
            $('#rules_table_view').show();
            $('#btn_mode_raw').removeClass('active');
            $('#btn_mode_table').addClass('active');
            currentMode = 'table';
        }
        updateCounter();
    }

    $('#btn_mode_table').on('click', function () {
        switchMode('table');
    });

    $('#btn_mode_raw').on('click', function () {
        switchMode('raw');
    });

    $('#btn_add_rule_row').on('click', function () {
        var $body = $('#tbl_rules_body');
        var defaultType = allowedRuleTypes[0] || 'DOMAIN-SUFFIX';
        var defaultTarget = allowedTargets[0] || 'DIRECT';
        var nextLine = $body.children().length + 1;
        var $row = createTableRow(defaultType, '', defaultTarget, false, nextLine);
        $body.append($row);
        reindexTableRows();
        updateCounter();
        $row.find('.rule-field-payload').focus();
    });

    function loadRules() {
        ajaxGet('/api/mihomo/rules/get', {}, function (data) {
            if (!data || data.status !== 'ok') {
                $('#rules_targets').empty().append(
                    $('<span class="text-danger"></span>').text('{{ lang._("Failed to load custom rules.") }}')
                );
                return;
            }
            if (data.limits && typeof data.limits === 'object') {
                var maxLines = parseInt(data.limits.maxLines, 10);
                var maxBytes = parseInt(data.limits.maxBytes, 10);
                if (!isNaN(maxLines) && maxLines > 0) {
                    rulesLimits.maxLines = maxLines;
                }
                if (!isNaN(maxBytes) && maxBytes > 0) {
                    rulesLimits.maxBytes = maxBytes;
                }
            }
            if (Array.isArray(data.ruleTypes)) {
                renderRuleTypes(data.ruleTypes);
            }
            renderTargets(data.targets);

            var initialContent = (typeof data.content === 'string') ? data.content : '';
            $('#rules_content').val(initialContent);
            parseTextToTable(initialContent);
            updateCounter();
            loadEffectiveRules();
        });
    }

    function renderEffectiveRules(rules) {
        var $body = $('#tbl_effective_body');
        $body.empty();
        var customPayloads = getCustomPayloadsSet();
        var filter = $.trim($('#filter_effective_rules').val() || '').toLowerCase();
        var count = 0;

        if (!Array.isArray(rules) || rules.length === 0) {
            var $emptyRow = $('<tr></tr>');
            var $emptyTd = $('<td colspan="5" class="text-center text-muted"></td>').text('{{ lang._("No effective rules found.") }}');
            $emptyRow.append($emptyTd);
            $body.append($emptyRow);
            $('#effective_count_label').text('{{ lang._("Total rules") }}: 0');
            return;
        }

        $.each(rules, function (idx, r) {
            var type = (r && r.type) ? String(r.type) : '';
            var payload = (r && r.payload) ? String(r.payload) : '';
            var proxy = (r && r.proxy) ? String(r.proxy) : '';

            if (filter !== '') {
                var match = type.toLowerCase().indexOf(filter) !== -1 ||
                            payload.toLowerCase().indexOf(filter) !== -1 ||
                            proxy.toLowerCase().indexOf(filter) !== -1;
                if (!match) {
                    return;
                }
            }

            count++;
            var $tr = $('<tr></tr>');

            var $tdIdx = $('<td style="text-align: center; vertical-align: middle;"></td>').text(idx + 1);
            $tr.append($tdIdx);

            var $tdType = $('<td style="vertical-align: middle;"></td>');
            $('<span class="label label-default"></span>').text(type).appendTo($tdType);
            $tr.append($tdType);

            var $tdPayload = $('<td style="vertical-align: middle; font-family: monospace;"></td>').text(payload);
            $tr.append($tdPayload);

            var $tdProxy = $('<td style="vertical-align: middle;"></td>');
            var $proxyBadge = $('<span class="label label-info"></span>').text(proxy);
            if (proxy === 'DIRECT') {
                $proxyBadge.removeClass('label-info').addClass('label-success');
            } else if (proxy === 'REJECT' || proxy === 'REJECT-DROP') {
                $proxyBadge.removeClass('label-info').addClass('label-danger');
            }
            $tdProxy.append($proxyBadge);
            $tr.append($tdProxy);

            var $tdSource = $('<td style="text-align: center; vertical-align: middle;"></td>');
            if (payload && customPayloads[payload]) {
                $('<span class="label label-warning"></span>').text('{{ lang._("Custom") }}').appendTo($tdSource);
            } else {
                $('<span class="text-muted">-</span>').appendTo($tdSource);
            }
            $tr.append($tdSource);

            $body.append($tr);
        });

        $('#effective_count_label').text('{{ lang._("Total rules") }}: ' + rules.length + (filter !== '' ? ' (' + count + ' matched)' : ''));
    }

    function loadEffectiveRules() {
        var $spinner = $('#effective_refresh_spinner');
        var $alert = $('#effective_rules_alert');
        $spinner.addClass('fa fa-spinner fa-spin');
        $alert.hide().empty();

        ajaxGet('/api/mihomo/rules/getEffectiveRules', {}, function (data) {
            $spinner.removeClass('fa fa-spinner fa-spin');
            if (!data || data.status !== 'ok') {
                $alert.removeClass('alert-warning').addClass('alert-danger')
                    .text('{{ lang._("Failed to fetch effective rules.") }}')
                    .show();
                return;
            }
            if (!data.reachable) {
                var note = (data.note) ? String(data.note) : '{{ lang._("Mihomo API unreachable") }}';
                $alert.removeClass('alert-danger').addClass('alert-warning')
                    .text(note)
                    .show();
                effectiveRulesCache = [];
                renderEffectiveRules([]);
                return;
            }
            effectiveRulesCache = Array.isArray(data.rules) ? data.rules : [];
            renderEffectiveRules(effectiveRulesCache);
        });
    }

    $('#btn_refresh_effective').on('click', function () {
        loadEffectiveRules();
    });

    $('#filter_effective_rules').on('input', function () {
        renderEffectiveRules(effectiveRulesCache);
    });

    $('#rules_content').on('input', updateCounter);

    $('#btn_rules_apply').click(function () {
        var content = (currentMode === 'table') ? serializeTableToText() : ($('#rules_content').val() || '');
        var $progress = $('#btn_rules_apply_progress');
        var $button = $('#btn_rules_apply');
        var $result = $('#rules_result');
        var $errorTable = $('#rules_error_table');
        var $errorBody = $('#rules_error_body');
        var $fileError = $('#rules_file_error');

        $progress.addClass('fa fa-spinner fa-pulse');
        $button.prop('disabled', true);
        $result.hide().removeClass('alert-success alert-danger alert-warning').empty();
        $fileError.hide().empty();
        $errorBody.empty();
        $errorTable.hide();
        $('.rule-row-error').hide().empty();

        ajaxCall('/api/mihomo/rules/set', {content: content}, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);

            if (data && data.status === 'ok') {
                $result.addClass('alert-success')
                    .text(data.message ? String(data.message) : '{{ lang._("Custom rules validated and applied.") }}')
                    .show();
                // 成功后同步更新 raw textarea 与刷新生效规则
                $('#rules_content').val(content);
                loadEffectiveRules();
                return;
            }

            var errors = (data && Array.isArray(data.errors)) ? data.errors : [];
            if (errors.length > 0) {
                $.each(errors, function (i, error) {
                    var lineNum = (error && error.line !== undefined && error.line !== null) ? parseInt(error.line, 10) : 0;
                    var msg = (error && error.message) ? String(error.message) : '';

                    if (lineNum === 0) {
                        // line=0 文件级错误显示在表格上方
                        $fileError.text(msg).show();
                    } else if (currentMode === 'table') {
                        // 映射回表格行内联显示
                        var $targetTr = $('#tbl_rules_body tr').filter(function () {
                            return $(this).attr('data-line') == lineNum;
                        });
                        if ($targetTr.length === 0) {
                            // 若没精确匹配到 data-line，则按行索引 (1-based)
                            $targetTr = $('#tbl_rules_body tr').eq(lineNum - 1);
                        }
                        if ($targetTr.length > 0) {
                            $targetTr.find('.rule-row-error').text(msg).show();
                        }
                    }

                    // 错误明细表仍保留展示
                    var $tr = $('<tr></tr>');
                    $('<td></td>').text(lineNum > 0 ? String(lineNum) : 'File').appendTo($tr);
                    $('<td></td>').text(msg).appendTo($tr);
                    $errorBody.append($tr);
                });
                $errorTable.show();
            }

            $result.addClass('alert-danger')
                .text((data && data.message) ? String(data.message) : '{{ lang._("Custom rules validation failed.") }}')
                .show();
        });
    });

    updateCounter();
    loadRules();
});
</script>
