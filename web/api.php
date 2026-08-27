<?php
session_start();
require __DIR__ . '/config.php';

function read_json_body(): array
{
    $raw = file_get_contents('php://input');
    if ($raw === false || trim($raw) === '') return [];
    $data = json_decode($raw, true);
    return is_array($data) ? $data : [];
}

function create_bank_request(string $action, array $data): array
{
    global $QUEUE_DIR, $RESULT_DIR, $BANK_TIMEOUT_SECONDS;
    if (!is_dir($QUEUE_DIR) && !@mkdir($QUEUE_DIR, 0777, true)) return [false, null, 'WEB_QUEUE_UNAVAILABLE'];
    if (!is_dir($RESULT_DIR) && !@mkdir($RESULT_DIR, 0777, true)) return [false, null, 'WEB_RESULT_UNAVAILABLE'];

    $requestId = 'WEB-' . bin2hex(random_bytes(12));
    $request = ['request_id'=>$requestId,'action'=>$action,'data'=>$data,'created_at'=>time()];
    $queueFile = $QUEUE_DIR . DIRECTORY_SEPARATOR . $requestId . '.json';
    $resultFile = $RESULT_DIR . DIRECTORY_SEPARATOR . $requestId . '.json';
    $payload = json_encode($request, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    if ($payload === false || @file_put_contents($queueFile, $payload, LOCK_EX) === false) return [false, null, 'WEB_QUEUE_WRITE_ERROR'];

    $deadline = microtime(true) + max(1, (int)$BANK_TIMEOUT_SECONDS);
    while (microtime(true) < $deadline) {
        if (is_file($resultFile)) {
            $raw = @file_get_contents($resultFile);
            @unlink($resultFile);
            @unlink($queueFile);
            if ($raw === false) return [false, null, 'WEB_RESULT_READ_ERROR'];
            $result = json_decode($raw, true);
            if (!is_array($result)) return [false, null, 'WEB_INVALID_BANK_RESPONSE'];
            return [true, $result, null];
        }
        usleep(200000);
    }

    @unlink($queueFile);
    return [false, null, 'BANK_WEB_TIMEOUT'];
}

function bank_error_to_text(string $error): string
{
    $map = [
        'ACCOUNT_NOT_FOUND'=>'Account not found',
        'CARD_NOT_FOUND'=>'Card not found',
        'CARD_BLOCKED'=>'Card is blocked',
        'ACCOUNT_BLOCKED'=>'Account is blocked',
        'INVALID_PIN'=>'Invalid PIN',
        'INSUFFICIENT_FUNDS'=>'Insufficient funds',
        'SOURCE_ACCOUNT_NOT_FOUND'=>'Source account not found',
        'DESTINATION_ACCOUNT_NOT_FOUND'=>'Destination account not found',
        'INVALID_AMOUNT'=>'Invalid amount',
        'SAME_ACCOUNT'=>'You cannot transfer to the same account',
        'BANK_SERVER_TIMEOUT'=>'Bank server timeout'
    ];
    return $map[$error] ?? $error;
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($method === 'GET') {
    $action = $_GET['action'] ?? 'session';
    if ($action === 'session') {
        if (!isset($_SESSION['bank_account_id'])) json_response(['success'=>false,'logged_in'=>false]);
        json_response(['success'=>true,'logged_in'=>true,'account_id'=>$_SESSION['bank_account_id'],'card_id'=>$_SESSION['bank_card_id'],'owner_name'=>$_SESSION['bank_owner_name'] ?? '']);
    }
    if ($action === 'logout') {
        $_SESSION=[];
        if (ini_get('session.use_cookies')) {
            $params=session_get_cookie_params();
            setcookie(session_name(), '', time()-42000, $params['path'], $params['domain'], $params['secure'], $params['httponly']);
        }
        session_destroy();
        json_response(['success'=>true]);
    }
    json_response(['success'=>false,'error'=>'UNKNOWN_ACTION'],400);
}

if ($method !== 'POST') json_response(['success'=>false,'error'=>'METHOD_NOT_ALLOWED'],405);

$body=read_json_body();
$action=(string)($body['action'] ?? '');

if ($action === 'login') {
    $accountId=trim((string)($body['account_id'] ?? ''));
    $pin=trim((string)($body['pin'] ?? ''));
    if (!preg_match('/^ACC-[0-9]{6}$/',$accountId) || !preg_match('/^\d{4}$/',$pin)) json_response(['success'=>false,'error'=>'INVALID_CREDENTIALS_FORMAT'],400);

    [$sent,$lookup,$err]=create_bank_request('account_lookup',['account_id'=>$accountId]);
    if (!$sent) json_response(['success'=>false,'error'=>$err],503);
    if (($lookup['ok'] ?? false)!==true) json_response(['success'=>false,'error'=>bank_error_to_text((string)($lookup['error'] ?? 'LOGIN_FAILED'))],401);

    $account=$lookup['data'] ?? [];
    $cardId=(string)($account['card_id'] ?? '');
    if ($cardId==='') json_response(['success'=>false,'error'=>'CARD_NOT_FOUND'],401);

    [$sent,$cardResult,$err]=create_bank_request('card_info',['card_id'=>$cardId,'pin'=>$pin]);
    if (!$sent) json_response(['success'=>false,'error'=>$err],503);
    if (($cardResult['ok'] ?? false)!==true) json_response(['success'=>false,'error'=>bank_error_to_text((string)($cardResult['error'] ?? 'LOGIN_FAILED'))],401);

    $data=$cardResult['data'] ?? [];
    $_SESSION['bank_account_id']=$accountId;
    $_SESSION['bank_card_id']=$cardId;
    $_SESSION['bank_owner_name']=$data['owner_name'] ?? ($account['owner_name'] ?? '');
    $_SESSION['bank_pin']=$pin;
    session_regenerate_id(true);
    json_response(['success'=>true,'account'=>$data]);
}

if (!isset($_SESSION['bank_account_id'],$_SESSION['bank_pin'],$_SESSION['bank_card_id'])) json_response(['success'=>false,'error'=>'NOT_LOGGED_IN'],401);

$cardId=$_SESSION['bank_card_id'];
$pin=$_SESSION['bank_pin'];

switch ($action) {
    case 'balance':
        [$sent,$result,$err]=create_bank_request('balance',['card_id'=>$cardId,'pin'=>$pin]);
        break;
    case 'transactions':
        $limit=max(1,min(50,(int)($body['limit'] ?? 20)));
        [$sent,$result,$err]=create_bank_request('transactions',['card_id'=>$cardId,'pin'=>$pin,'limit'=>$limit]);
        break;
    case 'transfer':
        $destination=trim((string)($body['destination_account_id'] ?? ''));
        $amount=(float)($body['amount'] ?? 0);
        $description=trim((string)($body['description'] ?? ''));
        if (!preg_match('/^ACC-[0-9]{6}$/',$destination) || $amount<=0) json_response(['success'=>false,'error'=>'INVALID_TRANSFER_DATA'],400);
        [$sent,$result,$err]=create_bank_request('transfer',['card_id'=>$cardId,'pin'=>$pin,'destination_account_id'=>$destination,'amount'=>$amount,'description'=>$description]);
        break;
    case 'block_card':
        [$sent,$result,$err]=create_bank_request('web_set_card_status',['card_id'=>$cardId,'pin'=>$pin,'status'=>'blocked']);
        break;
    default:
        json_response(['success'=>false,'error'=>'UNKNOWN_ACTION'],400);
}

if (!$sent) json_response(['success'=>false,'error'=>$err],503);
if (($result['ok'] ?? false)!==true) json_response(['success'=>false,'error'=>bank_error_to_text((string)($result['error'] ?? 'BANK_ERROR'))],400);
json_response(['success'=>true,'data'=>$result['data'] ?? null]);
