<?php
// ALBU BANK ONLINE configuration.
// Copy this web/ directory into your XAMPP htdocs folder.

// Shared secret used ONLY between web/bridge.php and web_bridge.lua.
// Change this value before using the bridge.
$BRIDGE_SECRET = 'CHANGE_THIS_ALBU_BANK_BRIDGE_SECRET';

// How long the web API waits for the Minecraft bank to answer.
$BANK_TIMEOUT_SECONDS = 20;

$DATA_DIR = __DIR__ . DIRECTORY_SEPARATOR . 'data';
$QUEUE_DIR = $DATA_DIR . DIRECTORY_SEPARATOR . 'queue';
$RESULT_DIR = $DATA_DIR . DIRECTORY_SEPARATOR . 'results';

if (!is_dir($QUEUE_DIR)) {
    @mkdir($QUEUE_DIR, 0777, true);
}
if (!is_dir($RESULT_DIR)) {
    @mkdir($RESULT_DIR, 0777, true);
}

function json_response(array $data, int $status = 200): void
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
