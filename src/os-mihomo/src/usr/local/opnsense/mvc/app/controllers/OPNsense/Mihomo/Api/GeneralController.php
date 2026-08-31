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
        return $this->setNodes('general');
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
