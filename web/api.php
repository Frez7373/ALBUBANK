<?php
session_start();
require __DIR__ . '/config.php';

function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') {
        return [];
    }
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function create_bank_request(string $action, array $data): array
{
    global $QUEUE_DIR, $RESULT_DIR, $BANK_TIMEOUT_SECONDS;

    if (!is_dir($QUEUE_DIR) && !@mkdir($QUEUE_DIR, 0777, true)) {
        return [false, null, 'WEB_QUEUE_UNAVAILABLE'];
    }
    if (!is_dir($RESULT_DIR) && !@mkdir($RESULT_DIR, 0777, true)) {
        return [false, null, 'WEB_RESULT_UNAVAILABLE'];
    }

    $requestId = 'WEB-' . bin2hex(random_bytes(12));
    $request = [
        'request_id' => $requestId,
        'action' => $action,
        'data' => $data,
        'created_at' => time()
    ];

    $queueFile = $QUEUE_DIR . DIRECTORY_SEPARATOR . $requestId . '.json';
    $resultFile = $RESULT_DIR . DIRECTORY_SEPARATOR . $requestId . '.json';

    $payload = json_encode($request, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    if ($payload === false || @file_put_contents($queueFile, $payload, LOCK_EX) === false) {
        return [false, null, 'WEB_QUEUE_WRITE_ERROR'];
    }

    $deadline = microtime(true) + max(1, (int)$BANK_TIMEOUT_SECONDS);
    while (microtime(true) < $deadline) {
        if (is_file($resultFile)) {
            $raw = @file_get_contents($resultFile);
            @unlink($resultFile);
            if ($raw === false) {
                @unlink($queueFile);
                return [false, null, 'WEB_RESULT_READ_ERROR'];
            }
            $result = json_decode($raw, true);
            @unlink($queueFile);
            if (!is_array($result)) {
                return [false, null, 'WEB_INVALID_BANK_RESPONSE'];
            }
            return [true, $result, null];
        }
        usleep(200000);
    }

    @unlink($queueFile);
    return [false, null, 'BANK_WEB_TIMEOUT'];
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'GET') {
    $action = $_GET['action'] ?? 'session';

    if ($action === 'session') {
        if (!isset($_SESSION['bank_account_id'])) {
            json_response(['success' => false, 'logged_in' => false]);
        }
        json_response([
            'success' => true,
            'logged_in' => true,
            'account_id' => $_SESSION['bank_account_id'],
            'card_id' => $_SESSION['bank_card_id'],
            'owner_name' => $_SESSION['bank_owner_name'] ?? ''
        ]);
    }

    if ($action === 'logout') {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000, $params['path'], $params['domain'], $params['secure'], $params['httponly']);
        }
        session_destroy();
        json_response(['success' => true]);
    }

    json_response(['success' => false, 'error' => 'UNKNOWN_ACTION'], 400);
}

if ($method !== 'POST') {
    json_response(['success' => false, 'error' => 'METHOD_NOT_ALLOWED'], 405);
}

$body = read_json_body();
$action = (string)($body['action'] ?? '');

if ($action === 'login') {
    $accountId = trim((string)($body['account_id'] ?? ''));
    $pin = trim((string)($body['pin'] ?? ''));

    if (!preg_match('/^ACC-[0-9]{6}$/', $accountId) || !preg_match('/^\d{4}$/', $pin)) {
        json_response(['success' => false, 'error' => 'INVALID_CREDENTIALS_FORMAT'], 400);
    }

    [$sent, $bankResult, $transportError] = create_bank_request('card_info', [
        'card_id' => lookup_card_id($accountId),
        'pin' => $pin
    ]);

    // The physical card ID is normally stored in the account record, but the
    // web login only has Account ID. Ask the bank for a small web lookup first.
    if (!$sent && $transportError !== null) {
        // Fall through to the explicit account login action implemented below.
    }

    [$sent, $bankResult, $transportError] = create_bank_request('web_login', [
        'account_id' => $accountId,
        'pin' => $pin
    ]);

    if (!$sent) {
        json_response(['success' => false, 'error' => $transportError], 503);
    }
    if (($bankResult['ok'] ?? false) !== true) {
        json_response(['success' => false, 'error' => $bankResult['error'] ?? 'LOGIN_FAILED'], 401);
    }

    $data = $bankResult['data'] ?? [];
    $_SESSION['bank_account_id'] = $accountId;
    $_SESSION['bank_card_id'] = $data['card_id'] ?? '';
    $_SESSION['bank_owner_name'] = $data['owner_name'] ?? '';
    $_SESSION['bank_pin'] = $pin;

    json_response(['success' => true, 'account' => $data]);
}

if (!isset($_SESSION['bank_account_id'], $_SESSION['bank_pin'], $_SESSION['bank_card_id'])) {
    json_response(['success' => false, 'error' => 'NOT_LOGGED_IN'], 401);
}

$accountId = $_SESSION['bank_account_id'];
$cardId = $_SESSION['bank_card_id'];
$pin = $_SESSION['bank_pin'];

switch ($action) {
    case 'balance':
        [$sent, $result, $err] = create_bank_request('balance', [
            'card_id' => $cardId,
            'pin' => $pin
        ]);
        break;

    case 'transactions':
        $limit = max(1, min(50, (int)($body['limit'] ?? 20)));
        [$sent, $result, $err] = create_bank_request('transactions', [
            'card_id' => $cardId,
            'pin' => $pin,
            'limit' => $limit
        ]);
        break;

    case 'transfer':
        $destination = trim((string)($body['destination_account_id'] ?? ''));
        $amount = (float)($body['amount'] ?? 0);
        $description = trim((string)($body['description'] ?? ''));
        if (!preg_match('/^ACC-[0-9]{6}$/', $destination) || $amount <= 0) {
            json_response(['success' => false, 'error' => 'INVALID_TRANSFER_DATA'], 400);
        }
        [$sent, $result, $err] = create_bank_request('transfer', [
            'card_id' => $cardId,
            'pin' => $pin,
            'destination_account_id' => $destination,
            'amount' => $amount,
            'description' => $description
        ]);
        break;

    case 'block_card':
        [$sent, $result, $err] = create_bank_request('web_set_card_status', [
            'card_id' => $cardId,
            'pin' => $pin,
            'status' => 'blocked'
        ]);
        break;

    default:
        json_response(['success' => false, 'error' => 'UNKNOWN_ACTION'], 400);
}

if (!$sent) {
    json_response(['success' => false, 'error' => $err], 503);
}
if (($result['ok'] ?? false) !== true) {
    json_response(['success' => false, 'error' => $result['error'] ?? 'BANK_ERROR'], 400);
}

json_response(['success' => true, 'data' => $result['data'] ?? null]);

function lookup_card_id(string $accountId): string
{
    // Kept local only as a compatibility placeholder. The real login action
    // uses web_login on the Minecraft bank, so this value is never trusted.
    return '';
}
