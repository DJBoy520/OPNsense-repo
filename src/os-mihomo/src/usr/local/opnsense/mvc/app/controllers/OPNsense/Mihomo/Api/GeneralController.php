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

use OPNsense\Base\ApiMutableModelControllerBase;
use OPNsense\Core\Backend;
use OPNsense\Mihomo\Mihomo;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\Mihomo\Mihomo';
    protected static $internalModelName = 'mihomo';

    public function getGeneralAction()
    {
        $result = $this->getNodes('general');
        $backend = new Backend();
        $maskedSecret = trim((string)$backend->configdRun('mihomo secret-masked'));
        if (empty($maskedSecret)) {
            $maskedSecret = 'NOT_CONFIGURED';
        }
        if (isset($result['mihomo']['general'])) {
            $result['mihomo']['general']['secret_masked'] = $maskedSecret;
        } else {
            $result['general']['secret_masked'] = $maskedSecret;
        }
        return $result;
    }

    public function setGeneralAction()
    {
        if (!$this->request->isPost()) {
            return ['result' => 'failed', 'status' => 'failed', 'message' => '仅接受 POST 请求'];
        }

        // 先快照旧值：后续动作只按“实际变化”分发
        $model = $this->getModel();
        $old = [
            'transport_mode' => (string)$model->general->transport_mode,
            'lan_expose' => (string)$model->general->lan_expose,
            'lan_user' => (string)$model->general->lan_user,
            'enabled' => (string)$model->general->enabled,
        ];

        try {
            $saveResult = $this->setNodes('general');
        } catch (\Exception $e) {
            return ['result' => 'failed', 'status' => 'failed', 'message' => '保存设置失败: ' . $e->getMessage()];
        }
        if (!isset($saveResult['result']) || $saveResult['result'] !== 'saved') {
            return [
                'result' => 'failed',
                'status' => 'failed',
                'message' => '保存设置失败',
                'validations' => isset($saveResult['validations']) ? $saveResult['validations'] : [],
            ];
        }

        // 重新加载模型，以配置文件中的新值为准
        $model = new Mihomo();
        $new = [
            'transport_mode' => (string)$model->general->transport_mode,
            'lan_expose' => (string)$model->general->lan_expose,
            'lan_user' => (string)$model->general->lan_user,
            'enabled' => (string)$model->general->enabled,
        ];

        $messages = [];
        $backend = new Backend();

        // 1) LAN 暴露状态文件：只允许白名单字符，不合法回落 mihomo
        if (!preg_match('/^[A-Za-z0-9_.@-]{1,32}$/', $new['lan_user'])) {
            $new['lan_user'] = 'mihomo';
        }
        $messages[] = $this->writePanelState($new['lan_expose'], $new['lan_user']);

        // 2) 传输模式切换（先 filter reload 再挂 anchor；关闭时反过来，避免规则引用悬空）
        if ($old['transport_mode'] !== $new['transport_mode']) {
            if ($new['transport_mode'] === 'transparent') {
                $messages[] = $this->runConfigd($backend, 'filter reload');
                $messages[] = $this->runConfigd($backend, 'mihomo transport-enable');
            } else {
                $messages[] = $this->runConfigd($backend, 'mihomo transport-disable');
                $messages[] = $this->runConfigd($backend, 'filter reload');
            }
        }

        // 3) LAN 暴露参数变化：按订阅缓存重组配置（绑定地址/认证用户来自模板）
        if ($old['lan_expose'] !== $new['lan_expose'] || $old['lan_user'] !== $new['lan_user']) {
            $messages[] = $this->runConfigd($backend, 'mihomo rules-recompose');
        }

        // 4) 服务启停（保留“保存即让 enabled 生效”的原语义）
        if ($new['enabled'] === '1') {
            $messages[] = $this->runConfigd($backend, 'mihomo restart');
        } elseif ($old['enabled'] !== '0') {
            $messages[] = $this->runConfigd($backend, 'mihomo stop');
        }

        return ['result' => 'saved', 'status' => 'ok', 'messages' => $messages];
    }

    /**
     * 写 /var/db/os-mihomo/panel-state.env（同目录 tmp + rename，0600）
     * 值已过白名单校验，单引号包裹是安全的。
     */
    private function writePanelState($lanExpose, $lanUser)
    {
        $stateFile = '/var/db/os-mihomo/panel-state.env';
        $stateDir = dirname($stateFile);
        if (!is_dir($stateDir)) {
            @mkdir($stateDir, 0750, true);
        }

        $tmpFile = tempnam($stateDir, '.panel-state.');
        if ($tmpFile === false) {
            return '写入面板状态失败: 无法在 ' . $stateDir . ' 创建临时文件';
        }
        // tempnam 在目标目录不可写时会退回到系统临时目录，必须同目录才能保证原子 rename
        if (dirname($tmpFile) !== $stateDir) {
            @unlink($tmpFile);
            return '写入面板状态失败: 目标目录不可写 ' . $stateDir;
        }

        chmod($tmpFile, 0600);
        $content = "MIHOMO_LAN_EXPOSE='" . ($lanExpose === '1' ? '1' : '0') . "'\n"
            . "MIHOMO_LAN_USER='" . $lanUser . "'\n";
        if (file_put_contents($tmpFile, $content, LOCK_EX) === false || !@rename($tmpFile, $stateFile)) {
            @unlink($tmpFile);
            return '写入面板状态失败: ' . $stateFile;
        }
        chmod($stateFile, 0600);
        return '面板状态已写入 ' . $stateFile;
    }

    /**
     * 执行 configd 动作并把结果带回消息数组（失败不中断后续动作）
     */
    private function runConfigd($backend, $command)
    {
        $output = $backend->configdRun($command);
        $text = is_string($output) ? trim($output) : '';
        if ($text === '') {
            return $command . ': 无输出（请核对服务日志）';
        }
        return $command . ': ' . $text;
    }

    public function regenerateSecretAction()
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $genOutput = trim((string)$backend->configdRun('mihomo secret-generate'));
            $maskedSecret = trim((string)$backend->configdRun('mihomo secret-masked'));
            return [
                'status' => 'ok',
                'message' => $genOutput,
                'secret_masked' => $maskedSecret ?: 'CONFIGURED'
            ];
        }
        return ['status' => 'failed', 'message' => 'Invalid request method'];
    }
}
