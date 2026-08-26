-- ALBU BANK - CENTRAL BANK SERVER
-- CC:Tweaked / Minecraft 1.16.5
--
-- This computer is the source of truth for all accounts.
-- Every bank account is stored in its own file under /albu_bank/accounts/.
-- Clients (ATM and Store Terminal) communicate only through the modem.

local modem = peripheral.find("modem")
local drive = peripheral.find("drive")

if not modem then
    error("ERROR: Modem not found")
end

local PORT = 4200
local NETWORK_NAME = "ALBU_BANK"
local DATA_ROOT = "/albu_bank"
local ACCOUNTS_DIR = DATA_ROOT .. "/accounts"
local CARDS_DIR = DATA_ROOT .. "/cards"
local TERMINALS_DIR = DATA_ROOT .. "/terminals"
local LOG_DIR = DATA_ROOT .. "/logs"
local NEXT_ACCOUNT_FILE = DATA_ROOT .. "/next_account.txt"
local NEXT_CARD_FILE = DATA_ROOT .. "/next_card.txt"
local ADMIN_FILE = DATA_ROOT .. "/admin.txt"

fs.makeDir(ACCOUNTS_DIR)
fs.makeDir(CARDS_DIR)
fs.makeDir(TERMINALS_DIR)
fs.makeDir(LOG_DIR)

local function saveTable(path, value)
    local h = fs.open(path, "w")
    if not h then return false end
    h.write(textutils.serialize(value))
    h.close()
    return true
end

local function loadTable(path)
    if not fs.exists(path) then return nil end
    local h = fs.open(path, "r")
    if not h then return nil end
    local raw = h.readAll()
    h.close()
    local ok, value = pcall(textutils.unserialize, raw)
    if ok then return value end
    return nil
end

local function writeNumber(path, number)
    local h = fs.open(path, "w")
    if not h then return false end
    h.write(tostring(number))
    h.close()
    return true
end

local function readNumber(path, default)
    if not fs.exists(path) then
        writeNumber(path, default)
        return default
    end
    local h = fs.open(path, "r")
    if not h then return default end
    local value = tonumber(h.readAll())
    h.close()
    return value or default
end

local function nextId(path, prefix)
    local number = readNumber(path, 1)
    writeNumber(path, number + 1)
    return prefix .. string.format("%06d", number)
end

local function accountPath(accountId)
    return ACCOUNTS_DIR .. "/" .. tostring(accountId) .. ".dat"
end

local function cardPath(cardId)
    return CARDS_DIR .. "/" .. tostring(cardId) .. ".dat"
end

local function terminalPath(terminalId)
    return TERMINALS_DIR .. "/" .. tostring(terminalId) .. ".dat"
end

local function generatePin()
    return tostring(math.random(0, 9)) .. tostring(math.random(0, 9)) .. tostring(math.random(0, 9)) .. tostring(math.random(0, 9))
end

local function now()
    return os.epoch("utc")
end

local function transactionId()
    return string.format("TX-%d-%04d", now(), math.random(0, 9999))
end

local function appendTransaction(tx)
    local file = LOG_DIR .. "/" .. tostring(tx.account_id) .. ".log"
    local h = fs.open(file, "a")
    if h then
        h.writeLine(textutils.serialize(tx))
        h.close()
    end
end

local function makeResponse(requestId, ok, data, err)
    return {
        type = "response",
        request_id = requestId,
        ok = ok,
        data = data,
        error = err
    }
end

local function getAccount(accountId)
    if type(accountId) ~= "string" or accountId == "" then return nil end
    return loadTable(accountPath(accountId))
end

local function getCard(cardId)
    if type(cardId) ~= "string" or cardId == "" then return nil end
    return loadTable(cardPath(cardId))
end

local function saveAccount(account)
    return saveTable(accountPath(account.id), account)
end

local function sanitizeAccount(account)
    if not account then return nil end
    return {
        id = account.id,
        owner_name = account.owner_name,
        balance = account.balance,
        currency = account.currency,
        card_id = account.card_id,
        status = account.status,
        created_at = account.created_at,
        updated_at = account.updated_at
    }
end

local function validateCard(cardId)
    local card = getCard(cardId)
    if not card then return nil, "CARD_NOT_FOUND" end
    if card.status ~= "active" then return nil, "CARD_BLOCKED" end
    local account = getAccount(card.account_id)
    if not account then return nil, "ACCOUNT_NOT_FOUND" end
    if account.status ~= "active" then return nil, "ACCOUNT_BLOCKED" end
    return card, account
end

local function createAccount(ownerName, initialBalance)
    ownerName = tostring(ownerName or "Unknown")
    initialBalance = tonumber(initialBalance or 0) or 0
    if initialBalance < 0 then return nil, "INVALID_INITIAL_BALANCE" end

    local accountId = nextId(NEXT_ACCOUNT_FILE, "ACC-")
    local cardId = nextId(NEXT_CARD_FILE, "CARD-")
    local pin = generatePin()

    local account = {
        id = accountId,
        owner_name = ownerName,
        balance = initialBalance,
        currency = "USD",
        card_id = cardId,
        status = "active",
        created_at = now(),
        updated_at = now()
    }

    local card = {
        id = cardId,
        account_id = accountId,
        owner_name = ownerName,
        pin = pin,
        status = "active",
        created_at = now()
    }

    if not saveAccount(account) then return nil, "ACCOUNT_FILE_ERROR" end
    if not saveTable(cardPath(cardId), card) then return nil, "CARD_FILE_ERROR" end
    appendTransaction({
        id = transactionId(), account_id = accountId, type = "account_created",
        amount = initialBalance, balance_after = initialBalance, currency = "USD",
        description = "Account created", timestamp = now()
    })

    return {
        account = sanitizeAccount(account),
        card = { id = cardId, pin = pin, account_id = accountId, owner_name = ownerName }
    }
end

local function cardInfo(cardId, pin)
    local card = getCard(cardId)
    if not card then return nil, "CARD_NOT_FOUND" end
    if card.status ~= "active" then return nil, "CARD_BLOCKED" end
    if pin ~= nil and tostring(pin) ~= tostring(card.pin) then return nil, "INVALID_PIN" end

    local account = getAccount(card.account_id)
    if not account then return nil, "ACCOUNT_NOT_FOUND" end

    return {
        card_id = card.id,
        account_id = account.id,
        owner_name = account.owner_name,
        balance = account.balance,
        currency = account.currency,
        card_status = card.status,
        account_status = account.status,
        created_at = account.created_at
    }
end

local function cardTransactions(cardId, pin, limit)
    local card = getCard(cardId)
    if not card then return nil, "CARD_NOT_FOUND" end
    if tostring(pin or "") ~= tostring(card.pin) then return nil, "INVALID_PIN" end

    local accountId = card.account_id
    local file = LOG_DIR .. "/" .. accountId .. ".log"
    if not fs.exists(file) then return {} end

    local h = fs.open(file, "r")
    if not h then return {} end
    local all = {}
    while true do
        local line = h.readLine()
        if not line then break end
        local ok, tx = pcall(textutils.unserialize, line)
        if ok and tx then table.insert(all, tx) end
    end
    h.close()

    local maxCount = tonumber(limit) or 10
    local result = {}
    local startIndex = math.max(1, #all - maxCount + 1)
    for i = startIndex, #all do
        table.insert(result, all[i])
    end
    return result
end

local function deposit(accountId, amount, description)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return nil, "INVALID_AMOUNT" end
    local account = getAccount(accountId)
    if not account then return nil, "ACCOUNT_NOT_FOUND" end
    if account.status ~= "active" then return nil, "ACCOUNT_BLOCKED" end

    account.balance = account.balance + amount
    account.updated_at = now()
    if not saveAccount(account) then return nil, "ACCOUNT_FILE_ERROR" end

    appendTransaction({
        id = transactionId(), account_id = accountId, type = "deposit",
        amount = amount, balance_after = account.balance, currency = account.currency,
        description = description or "Bank deposit", timestamp = now()
    })
    return sanitizeAccount(account)
end

local function withdraw(accountId, amount, description)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return nil, "INVALID_AMOUNT" end
    local account = getAccount(accountId)
    if not account then return nil, "ACCOUNT_NOT_FOUND" end
    if account.status ~= "active" then return nil, "ACCOUNT_BLOCKED" end
    if account.balance < amount then return nil, "INSUFFICIENT_FUNDS" end

    account.balance = account.balance - amount
    account.updated_at = now()
    if not saveAccount(account) then return nil, "ACCOUNT_FILE_ERROR" end

    appendTransaction({
        id = transactionId(), account_id = accountId, type = "withdraw",
        amount = amount, balance_after = account.balance, currency = account.currency,
        description = description or "Bank withdrawal", timestamp = now()
    })
    return sanitizeAccount(account)
end

local function transfer(fromAccountId, toAccountId, amount, description)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return nil, "INVALID_AMOUNT" end
    if fromAccountId == toAccountId then return nil, "SAME_ACCOUNT" end

    local from = getAccount(fromAccountId)
    local to = getAccount(toAccountId)
    if not from then return nil, "SOURCE_ACCOUNT_NOT_FOUND" end
    if not to then return nil, "DESTINATION_ACCOUNT_NOT_FOUND" end
    if from.status ~= "active" or to.status ~= "active" then return nil, "ACCOUNT_BLOCKED" end
    if from.balance < amount then return nil, "INSUFFICIENT_FUNDS" end

    from.balance = from.balance - amount
    to.balance = to.balance + amount
    from.updated_at = now()
    to.updated_at = now()

    if not saveAccount(from) then return nil, "SOURCE_ACCOUNT_FILE_ERROR" end
    if not saveAccount(to) then
        -- Try to roll back the source if destination save fails.
        from.balance = from.balance + amount
        from.updated_at = now()
        saveAccount(from)
        return nil, "DESTINATION_ACCOUNT_FILE_ERROR"
    end

    local tx = transactionId()
    appendTransaction({
        id = tx, account_id = from.id, type = "payment",
        amount = -amount, balance_after = from.balance, currency = from.currency,
        counterparty = to.id, description = description or "Payment", timestamp = now()
    })
    appendTransaction({
        id = tx, account_id = to.id, type = "payment_received",
        amount = amount, balance_after = to.balance, currency = to.currency,
        counterparty = from.id, description = description or "Payment received", timestamp = now()
    })

    return {
        transaction_id = tx,
        from = sanitizeAccount(from),
        to = sanitizeAccount(to),
        amount = amount
    }
end

local function registerTerminal(ownerCardId, ownerPin, terminalName)
    local card, accountOrError = validateCard(ownerCardId)
    if not card then return nil, accountOrError end
    local account = accountOrError
    if tostring(ownerPin or "") ~= tostring(card.pin) then return nil, "INVALID_PIN" end

    local terminalId = nextId(DATA_ROOT .. "/next_terminal.txt", "TERM-")
    local terminal = {
        id = terminalId,
        name = tostring(terminalName or "Store Terminal"),
        owner_account_id = account.id,
        owner_card_id = card.id,
        status = "active",
        created_at = now()
    }

    if not saveTable(terminalPath(terminalId), terminal) then
        return nil, "TERMINAL_FILE_ERROR"
    end
    return terminal
end

local function getTerminal(terminalId)
    return loadTable(terminalPath(terminalId))
end

local function processRequest(message)
    local requestId = message.request_id
    local action = message.action
    local data = message.data or {}

    if action == "ping" then
        return makeResponse(requestId, true, { server = NETWORK_NAME, time = now() })

    elseif action == "create_account" then
        local result, err = createAccount(data.owner_name, data.initial_balance)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "card_info" then
        local result, err = cardInfo(data.card_id, data.pin)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "balance" then
        local card, accountOrError = validateCard(data.card_id)
        if not card then return makeResponse(requestId, false, nil, accountOrError) end
        if tostring(data.pin or "") ~= tostring(card.pin) then return makeResponse(requestId, false, nil, "INVALID_PIN") end
        return makeResponse(requestId, true, sanitizeAccount(accountOrError))

    elseif action == "transactions" then
        local result, err = cardTransactions(data.card_id, data.pin, data.limit)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "deposit" then
        local result, err = deposit(data.account_id, data.amount, data.description)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "withdraw" then
        local result, err = withdraw(data.account_id, data.amount, data.description)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "register_terminal" then
        local result, err = registerTerminal(data.card_id, data.pin, data.terminal_name)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, result)

    elseif action == "terminal_info" then
        local terminal = getTerminal(data.terminal_id)
        if not terminal then return makeResponse(requestId, false, nil, "TERMINAL_NOT_FOUND") end
        return makeResponse(requestId, true, terminal)

    elseif action == "payment" then
        local terminal = getTerminal(data.terminal_id)
        if not terminal then return makeResponse(requestId, false, nil, "TERMINAL_NOT_FOUND") end
        if terminal.status ~= "active" then return makeResponse(requestId, false, nil, "TERMINAL_BLOCKED") end

        local card, accountOrError = validateCard(data.card_id)
        if not card then return makeResponse(requestId, false, nil, accountOrError) end
        if tostring(data.pin or "") ~= tostring(card.pin) then return makeResponse(requestId, false, nil, "INVALID_PIN") end

        local result, err = transfer(accountOrError.id, terminal.owner_account_id, data.amount, data.description or terminal.name)
        if not result then return makeResponse(requestId, false, nil, err) end
        return makeResponse(requestId, true, {
            transaction_id = result.transaction_id,
            amount = result.amount,
            customer = result.from,
            merchant = {
                account_id = result.to.id,
                owner_name = result.to.owner_name,
                terminal_id = terminal.id,
                terminal_name = terminal.name,
                balance = result.to.balance
            }
        })

    elseif action == "account_lookup" then
        local account = getAccount(data.account_id)
        if not account then return makeResponse(requestId, false, nil, "ACCOUNT_NOT_FOUND") end
        return makeResponse(requestId, true, sanitizeAccount(account))

    elseif action == "set_card_status" then
        local card = getCard(data.card_id)
        if not card then return makeResponse(requestId, false, nil, "CARD_NOT_FOUND") end
        local status = tostring(data.status or "active")
        if status ~= "active" and status ~= "blocked" then return makeResponse(requestId, false, nil, "INVALID_STATUS") end
        card.status = status
        if not saveTable(cardPath(card.id), card) then return makeResponse(requestId, false, nil, "CARD_FILE_ERROR") end
        return makeResponse(requestId, true, { card_id = card.id, status = card.status })

    else
        return makeResponse(requestId, false, nil, "UNKNOWN_ACTION")
    end
end

local function startup()
    math.randomseed(os.epoch("utc") % 2147483647)
    modem.open(PORT)
    term.clear()
    term.setCursorPos(1, 1)
    print("========================================")
    print("            ALBU BANK SERVER")
    print("========================================")
    print("Network : " .. NETWORK_NAME)
    print("Port    : " .. PORT)
    print("Data    : " .. DATA_ROOT)
    print("Status  : ONLINE")
    print("========================================")
end

startup()

while true do
    local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    if channel == PORT and type(message) == "table" and message.type == "request" then
        local response = processRequest(message)
        modem.transmit(replyChannel, PORT, response)
    end
end
