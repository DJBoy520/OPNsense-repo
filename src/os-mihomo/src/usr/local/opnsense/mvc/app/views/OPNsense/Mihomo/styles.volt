{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}
<style>
/* 基础页面容器 */
.mihomo-page {
    margin-top: 10px;
    margin-bottom: 25px;
    padding-bottom: 70px;
}
.mihomo-page .content-box {
    background-color: #ffffff;
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    color: #d94f00;
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
    border: 1px solid #e3e3e3;
    border-left: 3px solid #d94f00;
    border-radius: 6px;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
    margin-bottom: 20px;
    padding: 0;
    overflow: hidden;
}
.mihomo-card-head {
    padding: 12px 18px;
    background-color: #ffffff;
    border-bottom: 1px solid #e3e3e3;
    border-left: 4px solid #d94f00;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    border-bottom: 1px solid #e3e3e3;
    display: flex;
    align-items: center;
    gap: 6px;
}

/* 客户端访问指南卡片 */
.mihomo-guide {
    background-color: #fbfbfb;
    border: 1px solid #e3e3e3;
    border-left: 3px solid #d94f00;
    border-radius: 6px;
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
    border-radius: 4px;
    padding: 4px 10px;
    font-size: 12px;
    color: #333333;
    transition: all 0.15s ease-in-out;
}
.mihomo-chip.is-active {
    background-color: #fff3ec;
    border-color: #d94f00;
    color: #d94f00;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    background-color: #fff7f2;
    border-left: 3px solid #d94f00;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
    padding: 10px 12px;
    cursor: pointer;
    transition: all 0.15s ease-in-out;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
}
.mihomo-node:hover {
    border-color: #d94f00;
    box-shadow: 0 2px 5px rgba(217, 79, 0, 0.12);
}
.mihomo-node.is-current {
    background-color: #fff7f2;
    border-color: #d94f00;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    background-color: #fff7f2;
    color: #d94f00;
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
    border-radius: 4px;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
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
    border-bottom: 2px solid #e3e3e3;
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
    border: 1px solid #e3e3e3;
    border-radius: 6px;
    background-color: #ffffff;
}
.mihomo-table-wrap table thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    background-color: #f5f5f5;
    border-bottom: 2px solid #e3e3e3;
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
