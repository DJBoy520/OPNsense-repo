{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}
<style>
/* 设计 Token (DESIGN §4) */
:root {
    --mh-brand: #d94f00;
    --mh-brand-light: #fff7f2;
    --mh-brand-hover: #c44700;
    --mh-brand-ring: rgba(217, 79, 0, .15);
    --mh-success: #16a34a;
    --mh-success-bg: #f0fdf4;
    --mh-danger: #dc2626;
    --mh-danger-bg: #fef2f2;
    --mh-warning: #d97706;
    --mh-warning-bg: #fffbeb;
    --mh-info: #0284c7;
    --mh-info-bg: #f0f9ff;
    --mh-card-bg: #ffffff;
    --mh-card-border: #e3e3e3;
    --mh-text: #1e293b;
    --mh-muted: #64748b;
    --mh-radius: 8px;
    --mh-radius-sm: 4px;
}

/* 基础页面容器 */
.mihomo-page {
    margin-top: 10px;
    margin-bottom: 25px;
    padding-bottom: 70px;
}
.mihomo-page .content-box {
    background-color: #ffffff;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    margin-bottom: 20px;
    padding: 15px 20px;
}

/* 既有类名兼容 */
.mihomo-card-title {
    font-size: 16px;
    font-weight: 600;
    color: #333333;
    margin-top: 0;
    margin-bottom: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
}
.mihomo-card-title i.fa {
    color: var(--mh-brand);
    margin-right: 6px;
}
.mihomo-subtitle {
    font-size: 13px;
    color: #777777;
    margin-top: 6px;
    margin-bottom: 12px;
}
.mihomo-toolbar {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 10px;
    margin-bottom: 15px;
}
.mihomo-toolbar .form-group {
    margin-bottom: 0;
}
.mihomo-kpi {
    background-color: #fafafa;
    border: 1px solid var(--mh-card-border);
    border-left: 3px solid var(--mh-brand);
    border-radius: var(--mh-radius);
    padding: 12px 15px;
    margin-bottom: 15px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
    transition: all 0.2s ease-in-out;
}
.mihomo-kpi:hover {
    box-shadow: 0 2px 5px rgba(0, 0, 0, 0.08);
}
.mihomo-kpi-label {
    font-size: 12px;
    color: #777777;
    margin-bottom: 4px;
    font-weight: 500;
}
.mihomo-kpi-value {
    font-size: 18px;
    font-weight: 600;
    color: #333333;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.mihomo-mono {
    font-family: Menlo, Monaco, Consolas, 'Courier New', monospace;
}
.mihomo-nowrap {
    white-space: nowrap;
}

/* 统一卡片体系 */
.mihomo-card {
    background-color: #ffffff;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    margin-bottom: 20px;
    padding: 0;
    overflow: hidden;
}
.mihomo-card-head {
    padding: 12px 18px;
    background-color: #ffffff;
    border-bottom: 1px solid var(--mh-card-border);
    border-left: 4px solid var(--mh-brand);
    display: flex;
    align-items: center;
    justify-content: space-between;
}
.mihomo-card-head .mihomo-card-title {
    margin: 0;
    padding: 0;
    border-left: none;
    font-size: 16px;
    font-weight: 600;
    color: #333333;
}
.mihomo-card-body {
    padding: 16px 20px;
}

/* 表单外框容器 */
.mihomo-form-wrap {
    max-width: 760px;
}

/* Stat 网格体系（状态页等） */
.mihomo-stat-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 15px;
    margin-bottom: 15px;
}
.mihomo-stat {
    background-color: #fafafa;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    padding: 14px 16px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}
.mihomo-stat-label {
    font-size: 13px;
    color: #666666;
    margin-bottom: 8px;
    font-weight: 500;
}
.mihomo-stat-value {
    font-size: 16px;
    font-weight: 600;
    color: #333333;
}

/* Metric 网格体系（指标页等） */
.mihomo-metric-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 15px;
    margin-bottom: 15px;
}
.mihomo-metric {
    background-color: #fafafa;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    padding: 12px 14px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}

/* KV 紧凑两列表格体系 */
.mihomo-kv {
    width: 100%;
    margin-bottom: 0;
    border-collapse: separate;
    border-spacing: 0;
}
.mihomo-kv th,
.mihomo-kv td {
    padding: 8px 12px;
    font-size: 13px;
    line-height: 1.5;
    vertical-align: middle;
    border-top: 1px solid #eeeeee;
}
.mihomo-kv tr:first-child th,
.mihomo-kv tr:first-child td {
    border-top: none;
}
.mihomo-kv th {
    width: 150px;
    font-weight: 600;
    color: #555555;
    background-color: #fbfbfb;
    border-right: 1px solid #f0f0f0;
}
.mihomo-kv td {
    color: #333333;
    background-color: #ffffff;
}

/* 区块与分割 */
.mihomo-section {
    margin-top: 15px;
    margin-bottom: 10px;
}
.mihomo-section-title {
    font-size: 14px;
    font-weight: 600;
    color: #444444;
    padding-bottom: 6px;
    margin-bottom: 10px;
    border-bottom: 1px solid var(--mh-card-border);
    display: flex;
    align-items: center;
    gap: 6px;
}

/* 客户端访问指南卡片 */
.mihomo-guide {
    background-color: #fbfbfb;
    border: 1px solid var(--mh-card-border);
    border-left: 3px solid var(--mh-brand);
    border-radius: var(--mh-radius);
    padding: 12px 16px;
    margin-top: 12px;
    margin-bottom: 12px;
    font-size: 13px;
    color: #444444;
}
.mihomo-guide p {
    margin-bottom: 6px;
}
.mihomo-guide p:last-child {
    margin-bottom: 0;
}

/* 模式切换行 */
.mihomo-mode-row {
    display: flex;
    align-items: center;
    gap: 10px;
}

/* Chips 标签列表与标签 */
.mihomo-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
    align-items: center;
}
.mihomo-chips-scroll {
    flex-wrap: nowrap;
    overflow-x: auto;
    padding-bottom: 4px;
}
.mihomo-chips-scroll .mihomo-chip {
    flex: 0 0 auto;
}
.mihomo-chip {
    display: inline-flex;
    align-items: center;
    background-color: #f5f5f5;
    border: 1px solid #dcdcdc;
    border-radius: var(--mh-radius-sm);
    padding: 4px 10px;
    font-size: 12px;
    color: #333333;
    transition: all 0.15s ease-in-out;
}
.mihomo-chip.is-active {
    background-color: var(--mh-brand-light);
    border-color: var(--mh-brand);
    color: var(--mh-brand);
    font-weight: 600;
}

/* 策略组与节点布局 */
.mihomo-proxy-layout {
    display: flex;
    gap: 18px;
}
.mihomo-group-list {
    list-style: none;
    padding: 0;
    margin: 0;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    background-color: #ffffff;
    overflow: hidden;
}
.mihomo-group-item {
    padding: 10px 14px;
    border-bottom: 1px solid #eeeeee;
    cursor: pointer;
    transition: background-color 0.15s ease-in-out;
}
.mihomo-group-item:last-child {
    border-bottom: none;
}
.mihomo-group-item:hover {
    background-color: #f8f8f8;
}
.mihomo-group-item.is-active {
    background-color: var(--mh-brand-light);
    border-left: 3px solid var(--mh-brand);
    font-weight: 600;
}

/* 节点网格与节点卡片 */
.mihomo-node-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 12px;
}
.mihomo-node {
    background-color: #ffffff;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    padding: 10px 12px;
    cursor: pointer;
    transition: all 0.15s ease-in-out;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}
.mihomo-node:hover {
    border-color: var(--mh-brand);
    box-shadow: 0 2px 5px var(--mh-brand-ring);
}
.mihomo-node.is-current {
    background-color: var(--mh-brand-light);
    border-color: var(--mh-brand);
    border-width: 1.5px;
}
.mihomo-node.is-disabled {
    cursor: not-allowed;
    opacity: 0.6;
    background-color: #fafafa;
}

/* 延迟指示徽章 */
.mihomo-delay {
    font-size: 11px;
    padding: 2px 6px;
    border-radius: 3px;
    background-color: #eeeeee;
    color: #666666;
    font-family: Menlo, Monaco, Consolas, monospace;
}
.mihomo-delay.is-good {
    background-color: #e8f5e9;
    color: #2e7d32;
}
.mihomo-delay.is-warn {
    background-color: #fff8e1;
    color: #f57f17;
}
.mihomo-delay.is-bad {
    background-color: #ffebee;
    color: #c62828;
}

/* 选择器弹窗相关（规则页目标选择等） */
.mihomo-picker-search {
    margin-bottom: 12px;
}
.mihomo-picker-list {
    max-height: 380px;
    overflow-y: auto;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    list-style: none;
    padding: 0;
    margin: 0;
}
.mihomo-picker-item {
    padding: 8px 12px;
    border: 0;
    border-bottom: 1px solid #eeeeee;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    text-align: left;
    background-color: #ffffff;
}
.mihomo-picker-item:last-child {
    border-bottom: none;
}
.mihomo-picker-item:hover {
    background-color: #f8f8f8;
}
.mihomo-picker-item.is-active {
    background-color: var(--mh-brand-light);
    color: var(--mh-brand);
    font-weight: 600;
}
.mihomo-picker-section {
    padding: 8px 12px 4px;
    font-size: 11px;
    font-weight: 600;
    color: #999999;
}
.mihomo-picker-name {
    font-size: 13px;
}
.mihomo-picker-meta {
    margin-left: 12px;
    font-size: 11px;
    color: #888888;
}
.mihomo-chip-name {
    font-weight: 600;
}
.mihomo-chip-meta {
    margin-left: 8px;
    font-size: 11px;
    color: #888888;
}
.mihomo-target-cell {
    display: flex;
    flex-direction: column;
    gap: 4px;
}
.rule-target-picker {
    width: 100%;
    text-align: left;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
}
.rule-target-label {
    display: inline-block;
    max-width: 170px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    vertical-align: bottom;
}

/* 复制按钮与辅助组件 */
.mihomo-copy-btn {
    padding: 2px 8px;
    font-size: 12px;
    border-radius: var(--mh-radius-sm);
    cursor: pointer;
}
.mihomo-badge-warn {
    background-color: #fff3cd;
    color: #856404;
    border: 1px solid #ffeeba;
    padding: 2px 6px;
    border-radius: 3px;
    font-size: 12px;
}

/* 空状态 */
.mihomo-empty {
    text-align: center;
    color: #999999;
    padding: 24px;
    font-style: italic;
}

/* 日志与表格现有样式保留 */
.mihomo-log-view {
    max-height: 600px;
    overflow-y: auto;
    overflow-x: hidden;
    background-color: #ffffff;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    padding: 0;
}
.mihomo-log-table {
    margin-bottom: 0;
    width: 100%;
    border-collapse: collapse;
    font-family: Menlo, Monaco, Consolas, 'Courier New', monospace;
    font-size: 12px;
    background-color: #ffffff;
}
.mihomo-log-table thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    padding: 8px 10px;
    border: none;
    border-bottom: 2px solid var(--mh-card-border);
    font-weight: 600;
    color: #555555;
    background-color: #f5f5f5;
}
.mihomo-log-table tbody td {
    padding: 5px 10px;
    vertical-align: top;
    border: none;
    border-top: 1px solid #eeeeee;
}
.mihomo-log-table tbody tr:hover {
    background-color: #f9f9f9;
}
.mihomo-log-time {
    width: 185px;
    min-width: 185px;
    color: #777777;
    white-space: nowrap;
}
.mihomo-log-level {
    width: 80px;
    min-width: 80px;
    text-align: center;
    white-space: nowrap;
}
.mihomo-log-msg {
    color: #333333;
    white-space: pre-wrap;
    word-break: break-all;
}
.mihomo-table-wrap {
    max-height: 480px;
    overflow-y: auto;
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    background-color: #ffffff;
}
.mihomo-table-wrap table thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    background-color: #f5f5f5;
    border-bottom: 2px solid var(--mh-card-border);
}

/* ========================================================
   v1.3.0 新增 Dashboard 组件类
   ======================================================== */

/* Tab 导航容器美化 */
.mihomo-tabs-bar {
    background-color: var(--mh-card-bg);
    border-bottom: 1px solid var(--mh-card-border);
    margin-bottom: 20px;
    border-radius: var(--mh-radius) var(--mh-radius) 0 0;
}
.mihomo-tabs-bar.nav-tabs,
.mihomo-tabs-bar .nav-tabs {
    border-bottom: none;
    margin-bottom: 0;
}
.mihomo-tabs-bar.nav-tabs > li,
.mihomo-tabs-bar .nav-tabs > li {
    margin-bottom: 0;
}
.mihomo-tabs-bar.nav-tabs > li > a,
.mihomo-tabs-bar .nav-tabs > li > a {
    border: none;
    border-bottom: 2px solid transparent;
    border-radius: 0;
    color: var(--mh-muted);
    font-weight: 500;
    font-size: 14px;
    padding: 12px 20px;
    margin-right: 0;
    background: transparent;
    transition: all 0.15s ease-in-out;
}
.mihomo-tabs-bar.nav-tabs > li > a:hover,
.mihomo-tabs-bar .nav-tabs > li > a:hover {
    color: var(--mh-brand);
    border-bottom-color: transparent;
    background-color: var(--mh-brand-light);
}
.mihomo-tabs-bar.nav-tabs > li.active > a,
.mihomo-tabs-bar.nav-tabs > li.active > a:hover,
.mihomo-tabs-bar.nav-tabs > li.active > a:focus,
.mihomo-tabs-bar .nav-tabs > li.active > a,
.mihomo-tabs-bar .nav-tabs > li.active > a:hover,
.mihomo-tabs-bar .nav-tabs > li.active > a:focus {
    color: var(--mh-brand);
    border: none;
    border-bottom: 2px solid var(--mh-brand);
    background-color: transparent;
    font-weight: 600;
}

/* 状态指标卡 */
.mihomo-stat-card {
    min-height: 84px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 14px 18px;
    background-color: var(--mh-card-bg);
    border: 1px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04), 0 1px 2px rgba(0, 0, 0, 0.02);
    transition: transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
}
.mihomo-stat-card:hover {
    transform: translateY(-1px);
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.08), 0 2px 4px -1px rgba(0, 0, 0, 0.04);
}

/* 状态圆点与呼吸灯效果 */
.mihomo-status-dot {
    position: relative;
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background-color: #94a3b8;
    vertical-align: middle;
    flex-shrink: 0;
}
.mihomo-status-dot.is-running {
    background-color: var(--mh-success);
}
.mihomo-status-dot.is-running::after {
    content: '';
    position: absolute;
    top: -2px;
    left: -2px;
    right: -2px;
    bottom: -2px;
    border-radius: 50%;
    border: 2px solid var(--mh-success);
    opacity: 0.75;
    animation: mh-dot-pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}
.mihomo-status-dot.is-stopped {
    background-color: #94a3b8;
}
.mihomo-status-dot.is-error {
    background-color: var(--mh-danger);
}
@keyframes mh-dot-pulse {
    0%, 100% {
        transform: scale(1);
        opacity: 0.8;
    }
    50% {
        transform: scale(1.8);
        opacity: 0;
    }
}

/* 统计指标数字排印 */
.mihomo-stat-num {
    font-size: 26px;
    font-weight: 700;
    line-height: 1.15;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.02em;
    color: var(--mh-text);
}

/* 骨架占位扫光效果 */
.mihomo-skeleton {
    display: inline-block;
    width: 100%;
    min-height: 1em;
    border-radius: var(--mh-radius-sm);
    background: linear-gradient(90deg, #f1f5f9 25%, #e2e8f0 50%, #f1f5f9 75%);
    background-size: 200% 100%;
    animation: mh-shimmer 1.5s infinite;
}
@keyframes mh-shimmer {
    0% {
        background-position: 200% 0;
    }
    100% {
        background-position: -200% 0;
    }
}

/* 现代表单扁平化 (scoped base_form) */
.mihomo-modern-form .table-responsive {
    border: none;
    overflow: visible;
}
.mihomo-modern-form table.table {
    background-color: transparent;
    border: none;
    margin-bottom: 0;
}
.mihomo-modern-form table.table > colgroup {
    display: none;
}
.mihomo-modern-form table.table > thead > tr > th {
    border: none;
    padding: 16px 0 8px 0;
    color: var(--mh-text);
    font-size: 15px;
    font-weight: 600;
}
.mihomo-modern-form table.table > tbody {
    display: block;
}
.mihomo-modern-form table.table > tbody > tr {
    display: block;
    background: transparent !important;
    border: none;
    border-bottom: 1px dashed var(--mh-card-border);
    padding: 12px 0;
}
.mihomo-modern-form table.table > tbody > tr:last-child {
    border-bottom: none;
}
.mihomo-modern-form table.table > tbody > tr > td {
    display: block;
    width: 100% !important;
    border: none !important;
    padding: 3px 0 !important;
    background: transparent !important;
}
.mihomo-modern-form table.table > tbody > tr > td:first-child {
    font-size: 13px;
    font-weight: 600;
    color: var(--mh-text);
    padding-bottom: 6px !important;
}
.mihomo-modern-form table.table > tbody > tr > td:first-child .control-label {
    text-align: left;
    font-weight: 600;
    color: var(--mh-text);
    padding-top: 0;
}
.mihomo-modern-form table.table > tbody > tr > td:first-child a,
.mihomo-modern-form table.table > tbody > tr > td:first-child a.showhelp,
.mihomo-modern-form table.table > tbody > tr > td:first-child i.fa-info-circle {
    color: #94a3b8;
    margin-right: 4px;
}
.mihomo-modern-form .form-control,
.mihomo-modern-form .bootstrap-select > .btn {
    border-radius: 6px;
    border: 1px solid #cbd5e1;
    max-width: 460px;
    box-shadow: none;
    transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}
.mihomo-modern-form .bootstrap-select {
    max-width: 460px;
    width: 100% !important;
}
.mihomo-modern-form .form-control:focus,
.mihomo-modern-form .bootstrap-select > .btn:focus,
.mihomo-modern-form .bootstrap-select.open > .btn {
    border-color: var(--mh-brand);
    outline: none;
    box-shadow: 0 0 0 3px var(--mh-brand-ring);
}
.mihomo-modern-form table.table > tbody > tr input[type="checkbox"] {
    margin: 4px 0 0 0;
    width: 18px;
    height: 18px;
    cursor: pointer;
    vertical-align: middle;
}
.mihomo-modern-form table.table > tbody > tr:has(input[type="checkbox"]) {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 12px;
}
.mihomo-modern-form table.table > tbody > tr:has(input[type="checkbox"]) > td:first-child {
    display: inline-flex;
    align-items: center;
    width: auto !important;
    padding: 0 !important;
    margin: 0;
    order: 2;
}
.mihomo-modern-form table.table > tbody > tr:has(input[type="checkbox"]) > td:nth-child(2) {
    display: inline-flex;
    align-items: center;
    width: auto !important;
    padding: 0 !important;
    margin: 0;
    order: 1;
}
.mihomo-modern-form table.table > tbody > tr:has(input[type="checkbox"]) > td:nth-child(3) {
    display: block;
    width: 100% !important;
    order: 3;
    padding: 2px 0 0 0 !important;
}

/* 策略来源单选卡片组 */
.mihomo-radio-cards {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 14px;
    margin-top: 10px;
    margin-bottom: 15px;
}
.mihomo-radio-card {
    position: relative;
    display: flex;
    align-items: flex-start;
    padding: 14px 16px;
    background-color: var(--mh-card-bg);
    border: 1.5px solid var(--mh-card-border);
    border-radius: var(--mh-radius);
    cursor: pointer;
    transition: all 0.15s ease-in-out;
}
.mihomo-radio-card:hover {
    background-color: var(--mh-brand-light);
    border-color: #cbd5e1;
}
.mihomo-radio-card.is-active {
    border-color: var(--mh-brand);
    background-color: var(--mh-brand-light);
}
.mihomo-radio-indicator {
    width: 20px;
    height: 20px;
    border-radius: 50%;
    border: 2px solid #cbd5e1;
    margin-right: 12px;
    margin-top: 1px;
    flex-shrink: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: #ffffff;
    transition: all 0.15s ease-in-out;
}
.mihomo-radio-card.is-active .mihomo-radio-indicator {
    border-color: var(--mh-brand);
    background-color: var(--mh-brand);
}
.mihomo-radio-card.is-active .mihomo-radio-indicator::after {
    content: '';
    width: 6px;
    height: 10px;
    border: solid #ffffff;
    border-width: 0 2px 2px 0;
    transform: rotate(45deg);
    margin-bottom: 2px;
}
.mihomo-radio-title {
    font-size: 13px;
    font-weight: 600;
    color: var(--mh-text);
    margin-bottom: 4px;
    line-height: 1.4;
}
.mihomo-radio-desc {
    font-size: 12px;
    color: var(--mh-muted);
    line-height: 1.4;
    margin-bottom: 0;
}

/* 警告提示条 */
.mihomo-callout-warning {
    border-left: 4px solid var(--mh-warning);
    background-color: var(--mh-warning-bg);
    border-radius: var(--mh-radius-sm);
    font-size: 12px;
    color: #92400e;
    padding: 10px 14px;
    margin-top: 10px;
    margin-bottom: 12px;
    line-height: 1.5;
}
.mihomo-callout-warning i.fa {
    color: var(--mh-warning);
    margin-right: 6px;
}

/* 页面内保存成功横条 */
.mihomo-save-toast {
    display: none;
    background-color: var(--mh-success-bg);
    border-left: 4px solid var(--mh-success);
    color: var(--mh-success);
    border-radius: var(--mh-radius-sm);
    padding: 10px 16px;
    margin-bottom: 15px;
    font-size: 13px;
    font-weight: 500;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}
.mihomo-save-toast i.fa {
    color: var(--mh-success);
    margin-right: 6px;
}

/* 响应式断点（767px 以下单列） */
@media (max-width: 767px) {
    .mihomo-toolbar {
        flex-direction: column;
        align-items: stretch;
    }
    .mihomo-toolbar .btn-group,
    .mihomo-toolbar .form-group {
        width: 100%;
    }
    .mihomo-stat-grid {
        grid-template-columns: 1fr;
    }
    .mihomo-metric-grid {
        grid-template-columns: 1fr;
    }
    .mihomo-proxy-layout {
        flex-direction: column;
    }
    .mihomo-node-grid {
        grid-template-columns: 1fr;
    }
    .mihomo-radio-cards {
        grid-template-columns: 1fr;
    }
    .mihomo-kv th,
    .mihomo-kv td {
        display: block;
        width: 100%;
        border-right: none;
    }
    .mihomo-kv th {
        border-bottom: none;
        background-color: #f7f7f7;
    }
}
</style>
