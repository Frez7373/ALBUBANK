<?php
require __DIR__ . '/config.php';

function fail_bridge(string $error, int $status = 403): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok' => false, 'error' => $error], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$raw = file_get_contents('php://input');
$body = json_decode($raw ?: '', true);
if (!is_array($body)) {
    fail_bridge('INVALID_JSON', 400);
}

$secret = (string)($body['secret'] ?? '');
if ($secret === '' || !hash_equals($BRIDGE_SECRET, $secret)) {
    fail_bridge('INVALID_SECRET', 403);
}

$action = (string)($body['action'] ?? '');

if ($action === 'pull') {
    $files = @glob($QUEUE_DIR . DIRECTORY_SEPARATOR . 'WEB-*.json');
    if (!$files) {
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => true, 'request' => null], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    usort($files, static function ($a, $b) {
        return (@filemtime($a) ?: 0) <=> (@filemtime($b) ?: 0);
    });

    foreach ($files as $file) {
        $rawRequest = @file_get_contents($file);
        $request = json_decode($rawRequest ?: '', true);
        if (!is_array($request) || empty($request['request_id']) || empty($request['action'])) {
            @unlink($file);
            continue;
        }

        // Claim the request by renaming it. Only one bridge instance should
        // successfully claim a request.
        $claimed = $file . '.processing';
        if (!@rename($file, $claimed)) {
            continue;
        }

        $request['_claimed_file'] = basename($claimed);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => true, 'request' => $request], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok' => true, 'request' => null], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

if ($action === 'complete') {
    $requestId = preg_replace('/[^A-Za-z0-9_-]/', '', (string)($body['request_id'] ?? ''));
    if ($requestId === '') {
        fail_bridge('INVALID_REQUEST_ID', 400);
    }

    $response = $body['response'] ?? null;
    if (!is_array($response)) {
        fail_bridge('INVALID_RESPONSE', 400);
    }

    $resultFile = $RESULT_DIR . DIRECTORY_SEPARATOR . $requestId . '.json';
    $json = json_encode($response, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($json === false || @file_put_contents($resultFile, $json, LOCK_EX) === false) {
        fail_bridge('RESULT_WRITE_ERROR', 500);
    }

    $processingFile = $QUEUE_DIR . DIRECTORY_SEPARATOR . $requestId . '.json.processing';
    @unlink($processingFile);

    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['ok' => true], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

fail_bridge('UNKNOWN_BRIDGE_ACTION', 400);
