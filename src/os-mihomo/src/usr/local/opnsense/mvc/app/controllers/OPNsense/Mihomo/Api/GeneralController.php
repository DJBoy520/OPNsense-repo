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
use OPNsense\Core\Config;
use OPNsense\Mihomo\Mihomo;

class GeneralController extends ApiMutableModelControllerBase
{
    protected static $internalModelClass = '\OPNsense\Mihomo\Mihomo';
    protected static $internalModelName = 'mihomo';

    /**
     * 覆盖基类 getModelNodes，只暴露 general 子树，避免订阅 URL 等敏感信息被 General 子权限读取
     */
    protected function getModelNodes()
    {
        $nodes = $this->getModel()->getNodes();
        return [
            'general' => isset($nodes['general']) ? $nodes['general'] : []
        ];
    }

    /**
     * 覆盖基类 setAction，只接收并更新 mihomo.general 子树，防止跨节点篡改
     */
    public function setAction()
    {
        $result = ['result' => 'failed'];
        if ($this->request->isPost()) {
            $postData = $this->request->getPost(static::$internalModelName);
            if (!is_array($postData) || !isset($postData['general']) || !is_array($postData['general'])) {
                return $result;
            }

            Config::getInstance()->lock();
            $mdl = $this->getModel();
            $mdl->setNodes(['general' => $postData['general']]);
            $result = $this->validate();
            if (empty($result['result'])) {
                $this->setActionHook();
                return $this->save(false, true);
            }
        }
        return $result;
    }

    public function getGeneralAction()
    {
        /* 26.7 基类读走 getAction()（现通过 getModelNodes 只返回 general 子树） */
        $result = $this->getAction();
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
            /* 26.7 基类标准保存：构造模型→校验→setActionHook→落盘 */
            $saveResult = $this->setAction();
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

    /**
     * 刷新并热加载 mihomo 配置，确保 config.yaml 内的 secret 与 authentication 同步更新
     * 订阅缓存存在时先 recompose（重写 config.yaml），再显式 reload 确保生效
     */
    private function applySecretReload($backend)
    {
        $cacheFile = '/var/db/os-mihomo/subscription-cache.yaml';
        if (is_file($cacheFile) && filesize($cacheFile) > 0) {
            $recomposeOutput = trim((string)$backend->configdpRun('mihomo rules-recompose'));
            if (stripos($recomposeOutput, 'OK') === false) {
                return 'recompose failed: ' . ($recomposeOutput !== '' ? $recomposeOutput : '未收到合成响应');
            }
        }
        return trim((string)$backend->configdRun('mihomo reload'));
    }

    /**
     * 判断 reload 输出是否代表服务成功加载或启动
     */
    private function isReloadSuccess($output)
    {
        return stripos($output, 'SIGHUP') !== false ||
               stripos($output, 'Mihomo started successfully') !== false;
    }

    /**
     * 返回面板登录用的完整密钥（9090 external-controller）
     * 仅 page-services-mihomo* ACL 可达；与订阅 URL 不同，密钥必须能被
     * 管理员查看/复制，否则无法登录内置面板。
     * M7: 仅接受 POST 请求，受 CSRF 保护
     */
    public function secretRevealAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed', 'message' => '仅接受 POST 请求'];
        }
        $secret = trim((string)(new Backend())->configdRun('mihomo secret-get'));
        if ($secret === '') {
            return ['status' => 'failed', 'message' => '尚未配置 API 密钥'];
        }
        return ['status' => 'ok', 'secret' => $secret];
    }

    /**
     * 设置自定义密钥（b64 经 configd 传给 secret_manager.sh set），并热加载生效
     */
    public function secretSetAction()
    {
        if (!$this->request->isPost()) {
            return ['status' => 'failed', 'message' => '仅接受 POST 请求'];
        }

        $rawSecret = $this->request->getPost('secret');
        $nested = $this->request->getPost('mihomo');
        if (($rawSecret === '' || $rawSecret === null) && is_array($nested) && isset($nested['secret'])) {
            $rawSecret = $nested['secret'];
        }
        if (!is_string($rawSecret)) {
            return ['status' => 'failed', 'message' => '密钥格式无效，必须为字符串'];
        }
        $secret = trim($rawSecret);

        $length = strlen($secret);
        if ($length < 4 || $length > 128) {
            return ['status' => 'failed', 'message' => '密钥长度需在 4~128 个字符之间'];
        }
        if (preg_match('/\A[A-Za-z0-9._~@#%^+=:;,!?*-]+\z/', $secret) !== 1) {
            return [
                'status' => 'failed',
                'message' => '密钥仅允许字母数字与 . _ ~ @ # % ^ + = : ; , ! ? * -'
            ];
        }

        $backend = new Backend();
        $output = (string)$backend->configdpRun(
            'mihomo secret-set',
            ['b64:' . base64_encode($secret)]
        );
        if (stripos($output, 'OK') === false) {
            return ['status' => 'failed', 'message' => '写入密钥失败: ' . trim($output)];
        }

        // 订阅缓存存在时 recompose 再 reload；否则直接 reload。校验重载输出
        $reloadOutput = $this->applySecretReload($backend);
        if (!$this->isReloadSuccess($reloadOutput)) {
            return [
                'status' => 'failed',
                'message' => '密钥已写入，但热重载失败（旧配置仍在运行）: ' . ($reloadOutput !== '' ? $reloadOutput : '未收到服务响应')
            ];
        }
        $masked = trim((string)$backend->configdRun('mihomo secret-masked'));

        return [
            'status' => 'ok',
            'message' => 'API 密钥已更新' . ($reloadOutput !== '' ? '（' . $reloadOutput . '）' : ''),
            'secret_masked' => $masked !== '' ? $masked : 'CONFIGURED',
        ];
    }

    public function regenerateSecretAction()
    {
        if ($this->request->isPost()) {
            $backend = new Backend();
            $genOutput = trim((string)$backend->configdRun('mihomo secret-generate'));
            if (stripos($genOutput, 'OK') === false) {
                return ['status' => 'failed', 'message' => '生成密钥失败: ' . $genOutput];
            }
            $reloadOutput = $this->applySecretReload($backend);
            if (!$this->isReloadSuccess($reloadOutput)) {
                return [
                    'status' => 'failed',
                    'message' => '新密钥已生成，但热重载失败（旧配置仍在运行）: ' . ($reloadOutput !== '' ? $reloadOutput : '未收到服务响应')
                ];
            }
            $maskedSecret = trim((string)$backend->configdRun('mihomo secret-masked'));
            return [
                'status' => 'ok',
                'message' => $genOutput . ($reloadOutput !== '' ? '；已热加载 mihomo' : ''),
                /* 新密钥仅在本次响应中完整返回一次，供面板立即复制登录 */
                'secret' => trim((string)$backend->configdRun('mihomo secret-get')),
                'secret_masked' => $maskedSecret ?: 'CONFIGURED'
            ];
        }
        return ['status' => 'failed', 'message' => 'Invalid request method'];
    }
}
