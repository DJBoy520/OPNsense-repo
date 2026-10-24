{#
 # Copyright (C) 2024-2026 Deciso B.V.
 # All rights reserved.
 #}
<style>
.mihomo-page {
    margin-top: 10px;
    margin-bottom: 25px;
}
.mihomo-page .content-box {
    background-color: #ffffff;
    border: 1px solid #e3e3e3;
    border-radius: 4px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
    margin-bottom: 20px;
    padding: 15px 20px;
}
.mihomo-card-title {
    font-size: 17px;
    font-weight: 600;
    color: #333333;
    margin-top: 5px;
    margin-bottom: 8px;
    padding-left: 10px;
    border-left: 3px solid #d94f00;
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
    margin-bottom: 15px;
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
    border-radius: 4px;
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
.mihomo-log-view {
    max-height: 600px;
    overflow-y: auto;
    overflow-x: hidden;
    background-color: #ffffff;
    border: 1px solid #e3e3e3;
    border-radius: 4px;
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
    border-radius: 4px;
    background-color: #ffffff;
}
.mihomo-table-wrap table thead th {
    position: sticky;
    top: 0;
    z-index: 2;
    background-color: #f5f5f5;
    border-bottom: 2px solid #e3e3e3;
}
.mihomo-empty {
    text-align: center;
    color: #999999;
    padding: 20px;
    font-style: italic;
}
.mihomo-nowrap {
    white-space: nowrap;
}
@media (max-width: 767px) {
    .mihomo-toolbar {
        flex-direction: column;
        align-items: stretch;
    }
    .mihomo-toolbar .btn-group,
    .mihomo-toolbar .form-group {
        width: 100%;
    }
}
</style>
