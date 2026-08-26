-- ALBU BANK SERVER V2
-- CC:Tweaked / Minecraft 1.16.5

local modem = peripheral.find("modem")
if not modem then error("ERROR: Modem not found") end

local PORT = 4200
local ROOT = "/albu_bank"
local ACCOUNTS = ROOT .. "/accounts"
local CARDS = ROOT .. "/cards"
local TERMINALS = ROOT .. "/terminals"
local LOGS = ROOT .. "/logs"

fs.makeDir(ACCOUNTS)
fs.makeDir(CARDS)
fs.makeDir(TERMINALS)
fs.makeDir(LOGS)

local function save(path, value)
    local h = fs.open(path, "w")
    if not h then return false end
    h.write(textutils.serialize(value))
    h.close()
    return true
end

local function load(path)
    if not fs.exists(path) then return nil end
    local h = fs.open(path, "r")
    if not h then return nil end
    local raw = h.readAll()
    h.close()
    local ok, value = pcall(textutils.unserialize, raw)
    if ok and type(value) == "table" then return value end
    return nil
end

local function number(path, default)
    if not fs.exists(path) then save(path, default) return default end
    local h = fs.open(path, "r")
    local n = h and tonumber(h.readAll()) or nil
    if h then h.close() end
    return n or default
end

local function nextId(file, prefix)
    local n = number(ROOT .. "/" .. file, 1)
    save(ROOT .. "/" .. file, n + 1)
    return prefix .. string.format("%06d", n)
end

local function now() return os.epoch("utc") end
local function txid() return string.format("TX-%d-%04d", now(), math.random(0,9999)) end

local function accountPath(id) return ACCOUNTS .. "/" .. id .. ".dat" end
local function cardPath(id) return CARDS .. "/" .. id .. ".dat" end
local function terminalPath(id) return TERMINALS .. "/" .. id .. ".dat" end
local function logPath(id) return LOGS .. "/" .. id .. ".log" end

local function appendTx(accountId, tx)
    local h = fs.open(logPath(accountId), "a")
    if h then h.writeLine(textutils.serialize(tx)) h.close() end
end

local function response(id, ok, data, err)
    return {type="response", request_id=id, ok=ok, data=data, error=err}
end

local function account(id) return type(id)=="string" and load(accountPath(id)) or nil end
local function card(id) return type(id)=="string" and load(cardPath(id)) or nil end
local function terminal(id) return type(id)=="string" and load(terminalPath(id)) or nil end

local function safeAccount(a)
    if not a then return nil end
    return {id=a.id, owner_name=a.owner_name, balance=a.balance, currency=a.currency,
        card_id=a.card_id, status=a.status, created_at=a.created_at, updated_at=a.updated_at}
end

local function authenticateCard(cardId, pin)
    local c = card(cardId)
    if not c then return nil,nil,"CARD_NOT_FOUND" end
    if c.status ~= "active" then return nil,nil,"CARD_BLOCKED" end
    if tostring(c.pin) ~= tostring(pin or "") then return nil,nil,"INVALID_PIN" end
    local a = account(c.account_id)
    if not a then return nil,nil,"ACCOUNT_NOT_FOUND" end
    if a.status ~= "active" then return nil,nil,"ACCOUNT_BLOCKED" end
    return c,a,nil
end

local function validPin(pin)
    pin = tostring(pin or "")
    return pin:match("^%d%d%d%d$") ~= nil
end

local function createAccount(name, balance, wantedPin)
    name = tostring(name or "Unknown")
    balance = tonumber(balance)
    if name == "" then return nil,"INVALID_OWNER_NAME" end
    if not balance or balance < 0 then return nil,"INVALID_INITIAL_BALANCE" end
    if not validPin(wantedPin) then return nil,"INVALID_PIN_FORMAT" end

    local aid = nextId("next_account.txt","ACC-")
    local cid = nextId("next_card.txt","CARD-")
    local t = now()
    local a = {id=aid,owner_name=name,balance=balance,currency="USD",card_id=cid,status="active",created_at=t,updated_at=t}
    local c = {id=cid,account_id=aid,owner_name=name,pin=tostring(wantedPin),status="active",created_at=t}

    if not save(accountPath(aid),a) then return nil,"ACCOUNT_FILE_ERROR" end
    if not save(cardPath(cid),c) then fs.delete(accountPath(aid)) return nil,"CARD_FILE_ERROR" end

    appendTx(aid,{id=txid(),account_id=aid,type="account_created",amount=balance,balance_after=balance,currency="USD",description="Account created",timestamp=t})
    return {account=safeAccount(a),card={id=cid,account_id=aid,owner_name=name,pin=tostring(wantedPin)}}
end

local function changeBalance(aid, amount, mode, description)
    local a = account(aid)
    if not a then return nil,"ACCOUNT_NOT_FOUND" end
    if a.status ~= "active" then return nil,"ACCOUNT_BLOCKED" end
    amount = tonumber(amount)
    if not amount or amount <= 0 then return nil,"INVALID_AMOUNT" end
    if mode == "withdraw" and a.balance < amount then return nil,"INSUFFICIENT_FUNDS" end
    if mode == "withdraw" then a.balance = a.balance - amount else a.balance = a.balance + amount end
    a.updated_at = now()
    if not save(accountPath(a.id),a) then return nil,"ACCOUNT_FILE_ERROR" end
    appendTx(a.id,{id=txid(),account_id=a.id,type=mode,amount=(mode=="withdraw" and -amount or amount),balance_after=a.balance,currency=a.currency,description=description or mode,timestamp=now()})
    return safeAccount(a)
end

local function getTransactions(cardId,pin,limit)
    local c,a,err=authenticateCard(cardId,pin)
    if not c then return nil,err end
    local h=fs.open(logPath(a.id),"r")
    if not h then return {} end
    local list={}
    while true do
        local line=h.readLine()
        if not line then break end
        local ok,v=pcall(textutils.unserialize,line)
        if ok and type(v)=="table" then list[#list+1]=v end
    end
    h.close()
    local n=math.max(1,tonumber(limit) or 10)
    local out={}
    for i=math.max(1,#list-n+1),#list do out[#out+1]=list[i] end
    return out
end

local function registerTerminal(ownerCardId,ownerPin,name,existingId)
    local c,a,err=authenticateCard(ownerCardId,ownerPin)
    if not c then return nil,err end
    local id
    if existingId and existingId ~= "" then
        local old=terminal(existingId)
        if not old then return nil,"TERMINAL_NOT_FOUND" end
        if old.owner_account_id ~= a.id then return nil,"TERMINAL_OWNER_ONLY" end
        id=old.id
    else
        id=nextId("next_terminal.txt","TERM-")
    end
    local t={id=id,name=(name and name~="" and tostring(name) or "Store Terminal"),owner_account_id=a.id,owner_card_id=c.id,status="active",updated_at=now()}
    if not save(terminalPath(id),t) then return nil,"TERMINAL_FILE_ERROR" end
    return t
end

local function payment(data)
    local t=terminal(data.terminal_id)
    if not t then return nil,"TERMINAL_NOT_FOUND" end
    if t.status ~= "active" then return nil,"TERMINAL_BLOCKED" end
    local fromCard,from,err=authenticateCard(data.card_id,data.pin)
    if not fromCard then return nil,err end
    local to=account(t.owner_account_id)
    if not to then return nil,"MERCHANT_ACCOUNT_NOT_FOUND" end
    local amount=tonumber(data.amount)
    if not amount or amount<=0 then return nil,"INVALID_AMOUNT" end
    if from.id==to.id then return nil,"SAME_ACCOUNT" end
    if from.balance<amount then return nil,"INSUFFICIENT_FUNDS" end

    from.balance=from.balance-amount
    to.balance=to.balance+amount
    local tnow=now()
    from.updated_at=tnow to.updated_at=tnow
    if not save(accountPath(from.id),from) then return nil,"SOURCE_SAVE_ERROR" end
    if not save(accountPath(to.id),to) then
        from.balance=from.balance+amount
        save(accountPath(from.id),from)
        return nil,"DESTINATION_SAVE_ERROR"
    end

    local id=txid()
    local description=(data.description and data.description~="" and data.description or t.name)
    appendTx(from.id,{id=id,account_id=from.id,type="payment",amount=-amount,balance_after=from.balance,currency="USD",counterparty=to.id,description=description,timestamp=tnow})
    appendTx(to.id,{id=id,account_id=to.id,type="payment_received",amount=amount,balance_after=to.balance,currency="USD",counterparty=from.id,description=description,timestamp=tnow})
    return {transaction_id=id,amount=amount,customer=safeAccount(from),merchant={account_id=to.id,owner_name=to.owner_name,terminal_id=t.id,terminal_name=t.name,balance=to.balance}}
end

local function process(m)
    local d=m.data or {}
    local id=m.request_id
    if m.action=="ping" then return response(id,true,{server="ALBU_BANK",time=now()}) end
    if m.action=="create_account" then local r,e=createAccount(d.owner_name,d.initial_balance,d.pin); return response(id,r~=nil,r,e) end
    if m.action=="account_lookup" then local a=account(d.account_id); return response(id,a~=nil,safeAccount(a),a and nil or "ACCOUNT_NOT_FOUND") end
    if m.action=="card_info" then local c,a,e=authenticateCard(d.card_id,d.pin); if not c then return response(id,false,nil,e) end; return response(id,true,{card_id=c.id,account_id=a.id,owner_name=a.owner_name,balance=a.balance,currency=a.currency,card_status=c.status,account_status=a.status,created_at=a.created_at}) end
    if m.action=="balance" then local c,a,e=authenticateCard(d.card_id,d.pin); if not c then return response(id,false,nil,e) end; return response(id,true,safeAccount(a)) end
    if m.action=="transactions" then local r,e=getTransactions(d.card_id,d.pin,d.limit); return response(id,r~=nil,r,e) end
    if m.action=="deposit" then local r,e=changeBalance(d.account_id,d.amount,"deposit",d.description); return response(id,r~=nil,r,e) end
    if m.action=="withdraw" then local r,e=changeBalance(d.account_id,d.amount,"withdraw",d.description); return response(id,r~=nil,r,e) end
    if m.action=="set_card_status" then local c=card(d.card_id); if not c then return response(id,false,nil,"CARD_NOT_FOUND") end; if d.status~="active" and d.status~="blocked" then return response(id,false,nil,"INVALID_STATUS") end; c.status=d.status; save(cardPath(c.id),c); return response(id,true,{card_id=c.id,status=c.status}) end
    if m.action=="register_terminal" then local r,e=registerTerminal(d.card_id,d.pin,d.terminal_name); return response(id,r~=nil,r,e) end
    if m.action=="re_register_terminal" then local r,e=registerTerminal(d.owner_card_id,d.owner_pin,d.terminal_name,d.terminal_id); return response(id,r~=nil,r,e) end
    if m.action=="terminal_info" then local t=terminal(d.terminal_id); return response(id,t~=nil,t,t and nil or "TERMINAL_NOT_FOUND") end
    if m.action=="payment" then local r,e=payment(d); return response(id,r~=nil,r,e) end
    return response(id,false,nil,"UNKNOWN_ACTION")
end

math.randomseed((now()+os.getComputerID())%2147483647)
modem.open(PORT)
print("ALBU BANK SERVER V2 ONLINE")
print("Port: "..PORT)
while true do
    local _,_,ch,reply,msg=os.pullEvent("modem_message")
    if ch==PORT and type(msg)=="table" and msg.type=="request" then
        local ok,result=pcall(process,msg)
        if ok then modem.transmit(reply,PORT,result) else modem.transmit(reply,PORT,response(msg.request_id,false,nil,"SERVER_ERROR")) end
    end
end
