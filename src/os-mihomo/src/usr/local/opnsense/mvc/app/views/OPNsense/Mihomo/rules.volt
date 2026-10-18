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
            <code>DOMAIN</code>, <code>DOMAIN-SUFFIX</code>, <code>DOMAIN-KEYWORD</code>,
            <code>IP-CIDR</code>, <code>IP-CIDR6</code>, <code>GEOIP</code>, <code>GEOSITE</code>,
            <code>DST-PORT</code>
        </p>
        <div class="form-group">
            <label>{{ lang._('Allowed Targets') }}</label>
            <div id="rules_targets">
                <span class="text-muted"><i class="fa fa-spinner fa-spin"></i> {{ lang._('Loading...') }}</span>
            </div>
            <span class="help-block">{{ lang._('Only the targets listed above may be used as the last field of a rule.') }}</span>
        </div>
    </div>

    <div class="col-xs-12">
        <div class="form-group">
            <label for="rules_content">{{ lang._('Custom Rules') }}</label>
            <textarea id="rules_content" class="form-control" rows="16" spellcheck="false" style="font-family: Menlo, Monaco, Consolas, 'Courier New', monospace; font-size: 13px; line-height: 1.4; height: 320px; resize: vertical;"></textarea>
            <span class="help-block" id="rules_counter">{{ lang._('Lines') }}: 0 / 200 | {{ lang._('Bytes') }}: 0 / 32768</span>
            <span class="help-block">{{ lang._('One rule per line, for example: DOMAIN-SUFFIX,example.com,DIRECT. Lines starting with # are ignored.') }}</span>
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

<script>
$(function () {
    var rulesLimits = {
        maxLines: 200,
        maxBytes: 32768
    };

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
        var text = $('#rules_content').val() || '';
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
        var $box = $('#rules_targets');
        $box.empty();
        if (!Array.isArray(targets) || targets.length === 0) {
            $box.append($('<span class="text-muted"></span>').text('{{ lang._("No targets reported.") }}'));
            return;
        }
        $.each(targets, function (i, target) {
            if (i > 0) {
                $box.append(document.createTextNode(', '));
            }
            $('<span class="label label-info"></span>')
                .css({'display': 'inline-block', 'margin': '0 2px 2px 0', 'padding': '4px 7px'})
                .text(String(target))
                .appendTo($box);
        });
    }

    function loadRules() {
        ajaxGet('/api/mihomo/rules/get', {}, function (data) {
            if (!data || data.status !== 'ok') {
                $('#rules_targets').empty().append(
                    $('<span class="text-danger"></span>').text('{{ lang._("Failed to load custom rules.") }}')
                );
                return;
            }
            if (typeof data.content === 'string') {
                $('#rules_content').val(data.content);
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
            renderTargets(data.targets);
            updateCounter();
        });
    }

    $('#rules_content').on('input', updateCounter);

    $('#btn_rules_apply').click(function () {
        var content = $('#rules_content').val() || '';
        var $progress = $('#btn_rules_apply_progress');
        var $button = $('#btn_rules_apply');
        var $result = $('#rules_result');
        var $errorTable = $('#rules_error_table');
        var $errorBody = $('#rules_error_body');

        $progress.addClass('fa fa-spinner fa-pulse');
        $button.prop('disabled', true);
        $result.hide().removeClass('alert-success alert-danger alert-warning').empty();
        $errorBody.empty();
        $errorTable.hide();

        ajaxCall('/api/mihomo/rules/set', {content: content}, function (data) {
            $progress.removeClass('fa fa-spinner fa-pulse');
            $button.prop('disabled', false);
            if (data && data.status === 'ok') {
                $result.addClass('alert-success')
                    .text(data.message ? String(data.message) : '{{ lang._("Custom rules validated and applied.") }}')
                    .show();
                return;
            }
            var errors = (data && Array.isArray(data.errors)) ? data.errors : [];
            if (errors.length > 0) {
                $.each(errors, function (i, error) {
                    var $tr = $('<tr></tr>');
                    $('<td></td>').text((error && error.line !== undefined && error.line !== null) ? String(error.line) : '-').appendTo($tr);
                    $('<td></td>').text((error && error.message) ? String(error.message) : '').appendTo($tr);
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
