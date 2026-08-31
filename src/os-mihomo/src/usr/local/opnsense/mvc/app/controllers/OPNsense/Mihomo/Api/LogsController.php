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

class LogsController extends ApiControllerBase
{
    /**
     * Sanitize sensitive information from log lines (passwords, secrets, tokens, etc.)
     */
    private function sanitizeLogLine($line)
    {
        // Redact secret: "..." or secret: ...
        $line = preg_replace('/(secret:\s*["\']?)([^"\'\s]+)(["\']?)/i', '$1******$3', $line);
        // Redact password: "..."
        $line = preg_replace('/(password:\s*["\']?)([^"\'\s]+)(["\']?)/i', '$1******$3', $line);
        // Redact uuid / tokens / keys
        $line = preg_replace('/([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-)[a-f0-9]{12}/i', '$1************', $line);
        // Redact Bearer tokens
        $line = preg_replace('/(Bearer\s+)[A-Za-z0-9_\-\.]+/i', '$1******', $line);
        return $line;
    }

    /**
     * Get Mihomo logs with optional level filter and sensitive information masking
     */
    public function getLogsAction()
    {
        $level = strtolower($this->request->get('level', 'string', 'all'));
        $maxLines = (int)$this->request->get('limit', 'int', 500);
        if ($maxLines <= 0 || $maxLines > 2000) {
            $maxLines = 500;
        }

        $backend = new Backend();
        $rawLog = $backend->configdRun('mihomo log ' . $maxLines);

        if (empty($rawLog)) {
            return ['status' => 'ok', 'logs' => [], 'total' => 0];
        }

        $lines = preg_split("/\r\n|\n|\r/", $rawLog);
        $filtered = [];

        foreach ($lines as $line) {
            $trimmed = trim($line);
            if ($trimmed === '') {
                continue;
            }

            // Detect log level if present: [info], [warning], [error], [debug], etc.
            $lineLevel = 'info';
            if (preg_match('/\[(debug|info|warning|warn|error|fatal|silent)\]/i', $trimmed, $m)) {
                $lineLevel = strtolower($m[1]);
                if ($lineLevel === 'warn') {
                    $lineLevel = 'warning';
                }
            }

            if ($level !== 'all' && $level !== $lineLevel) {
                continue;
            }

            $sanitized = $this->sanitizeLogLine($trimmed);
            $filtered[] = [
                'level' => $lineLevel,
                'msg' => $sanitized,
            ];
        }

        return [
            'status' => 'ok',
            'logs' => $filtered,
            'total' => count($filtered),
        ];
    }
}
