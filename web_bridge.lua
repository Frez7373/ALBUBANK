-- ALBU BANK WEB BRIDGE
-- CC:Tweaked / Minecraft 1.16.5
-- The bridge polls the PHP site for web requests, executes them through
-- the existing ALBU BANK modem protocol, and posts the result back.

local API_URL = "http://CHANGE_TO_YOUR_RADMIN_IP/albubank/web/bridge.php"
local BRIDGE_SECRET = "CHANGE_THIS_ALBU_BANK_BRIDGE_SECRET"

local BANK_PORT = 4200
local POLL_SECONDS = 1
local BANK_TIMEOUT = 10

if not http then
    error("ERROR: HTTP API is disabled. Enable HTTP in CC:Tweaked.")
end

local modem = peripheral.find("modem")
if not modem then
    error("ERROR: Modem not found")
end

local function jsonPost(payload)
    local body = textutils.serializeJSON(payload)
    local response, err = http.post(API_URL, body, {
        ["Content-Type"] = "application/json"
    })
    if not response then
        return nil, err or "HTTP_ERROR"
    end

    local raw = response.readAll()
    response.close()

    if not raw or raw == "" then
        return nil, "EMPTY_HTTP_RESPONSE"
    end

    local ok, data = pcall(textutils.unserializeJSON, raw)
    if not ok or type(data) ~= "table" then
        return nil, "INVALID_JSON_RESPONSE"
    end

    return data
end

local function pullRequest()
    local result, err = jsonPost({
        secret = BRIDGE_SECRET,
        action = "pull"
    })

    if not result then
        print("[WEB] Pull failed: " .. tostring(err))
        return nil
    end

    if result.ok ~= true then
        print("[WEB] Pull rejected: " .. tostring(result.error))
        return nil
    end

    return result.request
end

local function callBank(request)
    local replyChannel = math.random(4300, 4999)
    modem.open(replyChannel)

    local message = {
        type = "request",
        request_id = request.request_id,
        action = request.action,
        data = request.data or {}
    }

    modem.transmit(BANK_PORT, replyChannel, message)

    local timerId = os.startTimer(BANK_TIMEOUT)
    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()

        if event == "modem_message" then
            local channel = p2
            local response = p4
            if channel == replyChannel and type(response) == "table" then
                if response.type == "response" and response.request_id == request.request_id then
                    modem.close(replyChannel)
                    return response
                end
            end
        elseif event == "timer" and p1 == timerId then
            modem.close(replyChannel)
            return {
                type = "response",
                request_id = request.request_id,
                ok = false,
                data = nil,
                error = "BANK_SERVER_TIMEOUT"
            }
        end
    end
end

local function completeRequest(requestId, response)
    local result, err = jsonPost({
        secret = BRIDGE_SECRET,
        action = "complete",
        request_id = requestId,
        response = response
    })

    if not result then
        print("[WEB] Complete failed: " .. tostring(err))
        return false
    end
    if result.ok ~= true then
        print("[WEB] Complete rejected: " .. tostring(result.error))
        return false
    end
    return true
end

math.randomseed((os.epoch("utc") + os.getComputerID()) % 2147483647)

print("========================================")
print("         ALBU BANK WEB BRIDGE")
print("========================================")
print("Web API: " .. API_URL)
print("Bank port: " .. BANK_PORT)
print("Status: ONLINE")
print("")

while true do
    local request = pullRequest()
    if request then
        print("[WEB] " .. tostring(request.request_id) .. " -> " .. tostring(request.action))
        local response = callBank(request)
        if completeRequest(request.request_id, response) then
            print("[WEB] Completed " .. tostring(request.request_id))
        end
    else
        sleep(POLL_SECONDS)
    end
end
