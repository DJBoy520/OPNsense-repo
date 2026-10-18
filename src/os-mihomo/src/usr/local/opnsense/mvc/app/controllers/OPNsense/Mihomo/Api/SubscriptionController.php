<?php

/*
 * Copyright (C) 2024-2026 Deciso B.V.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 * AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

namespace OPNsense\Mihomo\Api;

use OPNsense\Base\ApiControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Core\Config;
use OPNsense\Cron\Cron;
use OPNsense\Mihomo\Mihomo;

/**
 * 订阅管理 API（F1）
 *
 * 订阅 URL 的唯一真源是 MVC 模型；/usr/local/etc/mihomo/sub/env 由 configd 动作
 * mihomo sub-env-write 生成。自动更新任务通过 OPNsense 核心 Cron 模型写入
 * //OPNsense/cron（设计允许的唯一方式），不直接编辑 config.xml。
 */
class SubscriptionController extends ApiControllerBase
{
    /* 定时任务识别键：固定描述，改动会导致既有任务无法被识别 */
    const CRON_DESCRIPTION = 'os-mihomo auto sub-update';
    const CRON_COMMAND = 'mihomo sub-update';
    const STATUS_FILE = '/var/db/os-mihomo/last-sub-update.json';
    /* sub.sh 的 mkdir 锁目录，pid 文件为 <LOCK_DIR>/pid */
    const LOCK_DIR = '/var/run/mihomo-sub.lock';

    /**
     * 读取订阅配置与最近一次更新结果
     * url 只返回掩码形式，避免把订阅 token 暴露给浏览器。
     */
    public function getAction()
    {
        $model = new Mihomo();
        $url = (string)$model->subscription->url;

        $lastUpdate = null;
        if (is_file(self::STATUS_FILE) && is_readable(self::STATUS_FILE)) {
            $raw = @file_get_contents(self::STATUS_FILE);
            if ($raw !== false) {
                $decoded = json_decode($raw, true);
                if (is_array($decoded)) {
                    $lastUpdate = $decoded;
                }
            }
        }

        return [
            'status' => 'ok',
            'subscription' => [
                'has_url' => $url !== '',
                'url_masked' => $url !== '' ? $this->maskUrl($url) : '',
                'auto_update' => (int)(string)$model->subscription->auto_update,
                'auto_interval' => (string)$model->subscription->auto_interval,
            ],
            'last_update' => $lastUpdate,
        ];
    }

    /**
     * 保存订阅配置、写入 sub/env 并同步 cron 任务
     */
    public function setAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed', 'message' => '仅接受 POST 请求'];
        }

        $data = $this->readSubscriptionInput();
        foreach (['url', 'auto_update', 'auto_interval', 'clear_url'] as $key) {
            if (isset($data[$key]) && !is_scalar($data[$key])) {
                return ['status' => 'failed', 'message' => '订阅参数格式无效'];
            }
        }

        $model = new Mihomo();
        $currentUrl = (string)$model->subscription->url;

        // 空 url 语义：未提交或留空时保持原值（面板约定“留空=不修改”）；
        // 仅显式提交 clear_url=1 时才清空。
        $postedUrl = isset($data['url']) ? trim((string)$data['url']) : null;
        $clearUrl = isset($data['clear_url']) && (string)$data['clear_url'] === '1';
        if ($postedUrl === null || $postedUrl === '') {
            $url = $clearUrl ? '' : $currentUrl;
        } else {
            $url = $postedUrl;
        }

        if ($url !== '') {
            $error = $this->validateUrl($url);
            if ($error !== '') {
                return ['status' => 'failed', 'message' => $error];
            }
        }

        $rawAutoUpdate = isset($data['auto_update']) ? strtolower((string)$data['auto_update']) : '0';
        $autoUpdate = in_array($rawAutoUpdate, ['1', 'on', 'true', 'yes'], true) ? 1 : 0;
        $rawInterval = isset($data['auto_interval']) ? (string)$data['auto_interval'] : 'o24h';
        $interval = in_array($rawInterval, ['o6h', 'o12h', 'o24h'], true) ? $rawInterval : 'o24h';

        try {
            $model->subscription->url = $url;
            $model->subscription->auto_update = $autoUpdate ? '1' : '0';
            $model->subscription->auto_interval = $interval;
            $model->serializeToConfig();
            if (Config::getInstance()->save() === false) {
                throw new \Exception('config.xml 写入失败（可能被锁定）');
            }
        } catch (\Exception $e) {
            return ['status' => 'failed', 'message' => '保存订阅设置失败: ' . $e->getMessage()];
        }

        // env 由 PHP 写入器做第二份强校验与 POSIX 单引号转义
        if ($url !== '') {
            $backend = new Backend();
            $output = (string)$backend->configdRun(
                'mihomo sub-env-write',
                [$url, $autoUpdate ? '1' : '0', $interval]
            );
            if (stripos($output, 'OK') === false) {
                return [
                    'status' => 'failed',
                    'message' => '订阅设置已保存，但写入 sub/env 失败: ' . $this->truncate($output),
                ];
            }
        }

        try {
            $this->syncCronJob($autoUpdate, $interval);
        } catch (\Exception $e) {
            return [
                'status' => 'failed',
                'message' => '订阅设置已保存，但定时任务同步失败: ' . $e->getMessage(),
            ];
        }

        return [
            'status' => 'ok',
            'url_masked' => $url !== '' ? $this->maskUrl($url) : '',
            'message' => '订阅设置已保存',
        ];
    }

    /**
     * 异步触发一次订阅更新
     * 前端随后轮询 getAction 读取 last_update（sub.sh 负责写状态文件）。
     */
    public function updateAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed', 'message' => '仅接受 POST 请求'];
        }

        if ($this->isUpdateRunning()) {
            return ['status' => 'busy', 'message' => '订阅更新正在进行中，请稍候'];
        }

        // sub.sh 最坏约 10 分钟；detach 后请求立即返回，这里仍放宽脚本时限
        set_time_limit(300);
        (new Backend())->configdRun('mihomo sub-update', [], true);

        return ['status' => 'triggered', 'message' => '订阅更新已触发'];
    }

    /**
     * 兼容两种提交形态：扁平字段（面板手写 JS）与 mihomo[subscription][...]（表单序列化）
     */
    private function readSubscriptionInput()
    {
        $nested = $this->request->getPost('mihomo');
        if (
            is_array($nested) && isset($nested['subscription']) &&
            is_array($nested['subscription'])
        ) {
            return $nested['subscription'];
        }

        $flat = [];
        foreach (['url', 'auto_update', 'auto_interval', 'clear_url'] as $key) {
            $value = $this->request->getPost($key);
            if ($value !== null) {
                $flat[$key] = $value;
            }
        }
        return $flat;
    }

    /**
     * 服务端强校验：字符白名单 + FILTER_VALIDATE_URL + https 前缀 + 显式注入字符拒绝
     * 返回空字符串表示通过，否则返回中文原因。
     */
    private function validateUrl($url)
    {
        $pattern = '/\Ahttps:\/\/[0-9A-Za-z._~:\/?#\[\]@!$&()*+,;=%-]+\z/';
        if (!preg_match($pattern, $url)) {
            return '订阅地址包含不允许的字符（仅支持 https 且限定 URL 字符集）';
        }
        if (filter_var($url, FILTER_VALIDATE_URL) === false) {
            return '订阅地址不是合法的 URL';
        }
        if (strpos($url, 'https://') !== 0) {
            return '订阅地址必须以 https:// 开头';
        }
        foreach (["'", '"', '`'] as $forbidden) {
            if (strpos($url, $forbidden) !== false) {
                return '订阅地址不得包含引号或反引号';
            }
        }
        if (strpos($url, '$(') !== false) {
            return '订阅地址不得包含 $( 子串';
        }
        for ($i = 0, $length = strlen($url); $i < $length; $i++) {
            if (ord($url[$i]) < 33) {
                return '订阅地址不得包含空白或控制字符';
            }
        }
        return '';
    }

    /**
     * 生成 scheme://host/*** 形式的掩码（不暴露 path/query/token，也不暴露 userinfo）
     */
    private function maskUrl($url)
    {
        /* 分隔符必须用 ~：# 既做分隔符又出现在字符类 [^/?#] 中会让 preg_match 返回 false */
        $pattern = '~^([A-Za-z][A-Za-z0-9+.-]*://)(?:[^/?#]*@)?([^/?#]+)~';
        if (preg_match($pattern, $url, $matches)) {
            return $matches[1] . $matches[2] . '/***';
        }
        return '***';
    }

    /**
     * 幂等同步自动更新任务
     * auto_update=1：不存在则新建，存在则统一字段；
     * auto_update=0：显式偏差——仅禁用不删除，保留任务历史与 uuid。
     */
    private function syncCronJob($autoUpdate, $interval)
    {
        /* o24h 不能写 '*/24'：Cron 模型 hours 掩码仅允许 0-23，serializeToConfig 会抛
         * ValidationException；每日步长与 0 点等价，故映射为 '0' */
        $hoursMap = ['o6h' => '*/6', 'o12h' => '*/12', 'o24h' => '0'];
        $hours = isset($hoursMap[$interval]) ? $hoursMap[$interval] : '0';

        // OPNsense 核心模型类为 OPNsense\Cron\Cron（config.xml 挂载点 //OPNsense/cron）
        $cron = new Cron();
        $existing = [];
        foreach ($cron->jobs->job->iterateItems() as $job) {
            if ((string)$job->description === self::CRON_DESCRIPTION) {
                $existing[] = $job;
            }
        }

        $changed = false;
        if ($autoUpdate) {
            if (count($existing) === 0) {
                $existing[] = $cron->jobs->job->add();
            }
            foreach ($existing as $job) {
                $job->minutes = '0';
                $job->hours = $hours;
                $job->days = '*';
                $job->months = '*';
                $job->weekdays = '*';
                $job->command = self::CRON_COMMAND;
                $job->parameters = '';
                $job->enabled = '1';
                $job->description = self::CRON_DESCRIPTION;
            }
            $changed = true;
        } elseif (count($existing) > 0) {
            foreach ($existing as $job) {
                $job->enabled = '0';
            }
            $changed = true;
        }

        if ($changed) {
            $cron->serializeToConfig();
            if (Config::getInstance()->save() === false) {
                throw new \Exception('config.xml 写入失败（可能被锁定）');
            }
            (new Backend())->configdRun('cron regenerate');
        }
    }

    /**
     * 轻量防重复点击：锁目录存在且其中 pid 仍存活才算 busy。
     * 用 ps 判断而非 posix_kill(sig 0)，避免 Web 进程对 root 进程 EPERM 误判。
     */
    private function isUpdateRunning()
    {
        if (!is_dir(self::LOCK_DIR)) {
            return false;
        }
        $pidFile = self::LOCK_DIR . '/pid';
        if (!is_file($pidFile) || !is_readable($pidFile)) {
            return false;
        }
        $pid = (int)trim((string)@file_get_contents($pidFile));
        return $pid > 0 && $this->processAlive($pid);
    }

    /**
     * pid 来自锁文件，强制转 int 后再拼命令，避免任何注入
     */
    private function processAlive($pid)
    {
        $pid = (int)$pid;
        if ($pid <= 0) {
            return false;
        }
        $output = [];
        $returnCode = 1;
        @exec('/bin/ps -p ' . $pid . ' -o pid=', $output, $returnCode);
        return $returnCode === 0 && trim(implode('', $output)) !== '';
    }

    private function truncate($text, $limit = 300)
    {
        $text = trim((string)$text);
        if (strlen($text) > $limit) {
            return substr($text, 0, $limit) . '...';
        }
        return $text;
    }
}
