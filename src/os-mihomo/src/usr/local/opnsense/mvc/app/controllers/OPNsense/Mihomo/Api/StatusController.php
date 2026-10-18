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

class StatusController extends ApiControllerBase
{
    /**
     * Return detailed Mihomo runtime status (7 states, versions, TUN, API, memory, mode, etc.)
     */
    public function getMihomoStatusAction()
    {
        $backend = new Backend();

        // 1. Raw status & version from configd
        $rawStatus = trim($backend->configdRun('mihomo status'));
        $rawVersion = trim($backend->configdRun('mihomo version'));
        $rawSystemStatus = trim($backend->configdRun('mihomo system-status'));

        $pluginVersion = '1.0.5';
        $versionFile = '/usr/local/opnsense/version/mihomo';
        if (file_exists($versionFile)) {
            $versionData = json_decode(@file_get_contents($versionFile), true);
            if (isset($versionData['product_version'])) {
                $pluginVersion = $versionData['product_version'];
            }
        }

        // Direct state file inspection if accessible
        $stateFromFile = [];
        $stateFiles = ['/var/run/mihomo_state.json', '/var/db/os-mihomo/state.json'];
        foreach ($stateFiles as $sFile) {
            if (file_exists($sFile)) {
                $content = @file_get_contents($sFile);
                if (!empty($content)) {
                    $json = json_decode($content, true);
                    if (is_array($json)) {
                        $stateFromFile = $json;
                        break;
                    }
                }
            }
        }

        $parsed = [
            'status' => 'stopped',
            'state' => 'STOPPED',
            'mode' => 'DIRECT',
            'state_code' => 0,
            'state_desc' => 'STOPPED',
            'message' => '',
            'last_change' => '',
            'plugin_version' => $pluginVersion,
            'mihomo_version' => 'Unknown',
            'commit' => 'Unknown',
            'sha256' => 'Unknown',
            'pid' => null,
            'memory' => '0 MB',
            'uptime' => '0s',
            'tun_status' => 'DOWN',
            'api_status' => 'DOWN',
            'raw_status' => $rawStatus,
        ];

        // Merge state from file if read directly
        if (!empty($stateFromFile)) {
            $parsed = array_merge($parsed, $stateFromFile);
        }

        // Parse system-status json from configd
        if (!empty($rawSystemStatus)) {
            $sysData = json_decode($rawSystemStatus, true);
            if (is_array($sysData)) {
                $parsed = array_merge($parsed, $sysData);
            }
        }

        // Parse version output if not already parsed
        if ($parsed['mihomo_version'] === 'Unknown' && !empty($rawVersion)) {
            if (preg_match('/Mihomo(?: Meta)?\s+([^\s]+)/i', $rawVersion, $m)) {
                $parsed['mihomo_version'] = $m[1];
            }
            if (preg_match('/tags\/([^\s]+)/i', $rawVersion, $m)) {
                $parsed['mihomo_version'] = $m[1];
            }
            if (preg_match('/([0-9a-f]{7,40})/i', $rawVersion, $m)) {
                $parsed['commit'] = substr($m[1], 0, 7);
            }
        }

        // Calculate uptime and memory if PID exists
        if (!empty($parsed['pid']) && is_numeric($parsed['pid'])) {
            $pid = (int)$parsed['pid'];
            // Check process uptime via ps -o etime= -p <pid>
            $psUptime = @shell_exec(sprintf('ps -o etime= -p %d 2>/dev/null', $pid));
            if (!empty($psUptime)) {
                $parsed['uptime'] = trim($psUptime);
            }
        }

        // Ensure 7-state definitions:
        // DISABLED, STARTING, RUNNING, DEGRADED, STOPPING, STOPPED, FAILED
        $stateUpper = strtoupper($parsed['state'] ?? 'STOPPED');
        $parsed['state'] = $stateUpper;

        switch ($stateUpper) {
            case 'DISABLED':
                $parsed['state_code'] = -1;
                $parsed['status'] = 'disabled';
                $parsed['state_desc'] = 'Disabled';
                $parsed['mode'] = $parsed['mode'] ?: 'DIRECT';
                break;
            case 'STARTING':
                $parsed['state_code'] = 1;
                $parsed['status'] = 'starting';
                $parsed['state_desc'] = 'Starting';
                $parsed['mode'] = $parsed['mode'] ?: 'DIRECT';
                break;
            case 'RUNNING':
                $parsed['state_code'] = 2;
                $parsed['status'] = 'running';
                $parsed['state_desc'] = 'Running';
                $parsed['mode'] = $parsed['mode'] ?: 'PROXY';
                break;
            case 'DEGRADED':
                $parsed['state_code'] = 3;
                $parsed['status'] = 'degraded';
                $parsed['state_desc'] = 'Degraded';
                break;
            case 'STOPPING':
                $parsed['state_code'] = 4;
                $parsed['status'] = 'stopping';
                $parsed['state_desc'] = 'Stopping';
                $parsed['mode'] = 'DIRECT';
                break;
            case 'STOPPED':
                $parsed['state_code'] = 0;
                $parsed['status'] = 'stopped';
                $parsed['state_desc'] = 'Stopped';
                $parsed['mode'] = 'DIRECT';
                break;
            case 'FAILED':
                $parsed['state_code'] = 5;
                $parsed['status'] = 'failed';
                $parsed['state_desc'] = 'Failed';
                $parsed['mode'] = 'DIRECT';
                break;
            default:
                $parsed['state_code'] = 0;
                $parsed['status'] = 'stopped';
                $parsed['state_desc'] = 'Stopped';
                $parsed['mode'] = 'DIRECT';
                break;
        }

        return $parsed;
    }
}
