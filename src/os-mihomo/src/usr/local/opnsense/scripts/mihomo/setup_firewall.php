#!/usr/local/bin/php
<?php

const CONFIG_FILE = '/conf/config.xml';
const TUN_DEVICE = 'tun_mihomo';
const RULE_UUID = '5a73c3dc-69b1-4e15-89cb-b542aa2c1154';

function childElement(DOMDocument $doc, DOMElement $parent, string $name, string $value = ''): DOMElement
{
    $node = $doc->createElement($name);
    if ($value !== '') {
        $node->appendChild($doc->createTextNode($value));
    }
    $parent->appendChild($node);
    return $node;
}

function setChild(DOMDocument $doc, DOMElement $parent, string $name, string $value): void
{
    foreach ($parent->childNodes as $child) {
        if ($child instanceof DOMElement && $child->tagName === $name) {
            $child->nodeValue = $value;
            return;
        }
    }
    childElement($doc, $parent, $name, $value);
}

$mode = $argv[1] ?? '';
if (!in_array($mode, ['install', 'uninstall'], true)) {
    fwrite(STDERR, "usage: setup_firewall.php install|uninstall\n");
    exit(64);
}

$lock = fopen('/var/run/os-mihomo-firewall.lock', 'c');
if ($lock === false || !flock($lock, LOCK_EX)) {
    fwrite(STDERR, "unable to lock firewall configuration\n");
    exit(1);
}

$doc = new DOMDocument();
$doc->preserveWhiteSpace = true;
if (!file_exists(CONFIG_FILE) || !$doc->load(CONFIG_FILE)) {
    fwrite(STDERR, "unable to read " . CONFIG_FILE . "\n");
    exit(1);
}
$xpath = new DOMXPath($doc);

if ($mode === 'install') {
    // 1. Check or add interface
    $interfacesNode = $xpath->query('/opnsense/interfaces')->item(0);
    if (!$interfacesNode instanceof DOMElement) {
        fwrite(STDERR, "interfaces node not found\n");
        exit(1);
    }

    $existingTunIf = null;
    $maxOpt = -1;

    foreach ($interfacesNode->childNodes as $child) {
        if ($child instanceof DOMElement) {
            $tag = $child->tagName;
            if (preg_match('/^opt(\d+)$/', $tag, $m)) {
                $optNum = (int)$m[1];
                if ($optNum > $maxOpt) {
                    $maxOpt = $optNum;
                }
            }
            $ifEl = $xpath->query('./if', $child)->item(0);
            if ($ifEl instanceof DOMElement && trim($ifEl->textContent) === TUN_DEVICE) {
                $existingTunIf = $tag;
            }
        }
    }

    $targetIf = $existingTunIf;
    if ($targetIf === null) {
        $targetIf = 'opt' . ($maxOpt + 1);
        $newIfNode = $doc->createElement($targetIf);
        setChild($doc, $newIfNode, 'if', TUN_DEVICE);
        setChild($doc, $newIfNode, 'descr', 'TUN');
        setChild($doc, $newIfNode, 'enable', '1');
        $interfacesNode->appendChild($newIfNode);
    }

    // 2. Check or add filter rule
    $filterNode = $xpath->query('/opnsense/filter')->item(0);
    if (!$filterNode instanceof DOMElement) {
        $opnNode = $xpath->query('/opnsense')->item(0);
        if ($opnNode instanceof DOMElement) {
            $filterNode = $doc->createElement('filter');
            $opnNode->appendChild($filterNode);
        }
    }

    if ($filterNode instanceof DOMElement) {
        $existingRule = $xpath->query('./rule[@uuid="' . RULE_UUID . '"]', $filterNode)->item(0);
        if (!$existingRule instanceof DOMElement) {
            $ruleNode = $doc->createElement('rule');
            $ruleNode->setAttribute('uuid', RULE_UUID);
            setChild($doc, $ruleNode, 'type', 'pass');
            setChild($doc, $ruleNode, 'interface', $targetIf);
            setChild($doc, $ruleNode, 'ipprotocol', 'inet');
            
            $sourceNode = $doc->createElement('source');
            childElement($doc, $sourceNode, 'network', $targetIf);
            $ruleNode->appendChild($sourceNode);

            $destNode = $doc->createElement('destination');
            childElement($doc, $destNode, 'any');
            $ruleNode->appendChild($destNode);

            setChild($doc, $ruleNode, 'descr', 'Mihomo TUN Allow');

            // Insert rule at top or append
            if ($filterNode->firstChild) {
                $filterNode->insertBefore($ruleNode, $filterNode->firstChild);
            } else {
                $filterNode->appendChild($ruleNode);
            }
        }
    }
} else {
    // Mode: uninstall
    // 1. Remove interface
    $ifNodes = $xpath->query('/opnsense/interfaces/*[if="' . TUN_DEVICE . '"]');
    foreach (iterator_to_array($ifNodes) as $node) {
        $node->parentNode->removeChild($node);
    }

    // 2. Remove rule
    $ruleNodes = $xpath->query('/opnsense/filter/rule[@uuid="' . RULE_UUID . '"]');
    foreach (iterator_to_array($ruleNodes) as $node) {
        $node->parentNode->removeChild($node);
    }

    // 3. Remove legacy cron items if any
    $cronItems = $xpath->query('/opnsense/cron/item');
    foreach (iterator_to_array($cronItems) as $item) {
        $commandNode = $xpath->query('./command', $item)->item(0);
        $descrNode = $xpath->query('./description', $item)->item(0);
        $cmdText = $commandNode ? $commandNode->textContent : '';
        $descText = $descrNode ? $descrNode->textContent : '';
        if (
            preg_match('/Renew mihomo Subscription|mihomo[ _-]?[Ss]ubscription|mihomo_sub|mihomo sub-update|\/usr\/bin\/mihomo_sub/', $cmdText . ' ' . $descText)
        ) {
            $item->parentNode->removeChild($item);
        }
    }
}

$backup = CONFIG_FILE . '.bak.os-mihomo-fw-' . date('Ymd-His');
copy(CONFIG_FILE, $backup);
$temp = CONFIG_FILE . '.os-mihomo.tmp';
if ($doc->save($temp) === false || !rename($temp, CONFIG_FILE)) {
    @unlink($temp);
    fwrite(STDERR, "unable to update " . CONFIG_FILE . "\n");
    exit(1);
}
