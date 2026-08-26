-- ALBU BANK CLIENT LIBRARY
-- Shared by ATM and Store Terminal.

local M = {}

M.PORT = 4200
M.NETWORK_NAME = "ALBU_BANK"

local function getModem()
    local modem = peripheral.find("modem")
    if not modem then error("ERROR: Modem not found") end
    return modem
end

local function makeRequestId()
    return string.format("REQ-%d-%04d", os.epoch("utc"), math.random(0, 9999))
end

function M.request(action, data, timeout)
    local modem = getModem()
    timeout = timeout or 5
    math.randomseed((os.epoch("utc") + os.getComputerID()) % 2147483647)

    local replyChannel = math.random(4300, 4999)
    local requestId = makeRequestId()
    local message = {
        type = "request",
        request_id = requestId,
        action = action,
        data = data or {}
    }

    modem.open(replyChannel)
    modem.transmit(M.PORT, replyChannel, message)

    local deadline = os.epoch("utc") + timeout * 1000
    while os.epoch("utc") < deadline do
        local remaining = math.max(0.1, (deadline - os.epoch("utc")) / 1000)
        local event, side, channel, reply, response = os.pullEvent("modem_message")
        if channel == replyChannel and type(response) == "table" then
            if response.type == "response" and response.request_id == requestId then
                modem.close(replyChannel)
                return response.ok, response.data, response.error
            end
        end
        if remaining <= 0 then break end
    end

    modem.close(replyChannel)
    return false, nil, "BANK_SERVER_TIMEOUT"
end

function M.promptPin()
    term.write("PIN: ")
    local pin = read("*")
    return pin
end

function M.readCardFromDrive()
    local drive = peripheral.find("drive")
    if not drive then return nil, "DISK_DRIVE_NOT_FOUND" end
    if not drive.isDiskPresent() then return nil, "CARD_NOT_INSERTED" end

    local mount = drive.getMountPath()
    if not mount then return nil, "CARD_NOT_MOUNTED" end

    local function read(path)
        if not fs.exists(path) then return nil end
        local h = fs.open(path, "r")
        if not h then return nil end
        local raw = h.readAll()
        h.close()
        local ok, value = pcall(textutils.unserialize, raw)
        if ok then return value end
        return nil
    end

    local card = read(mount .. "/albu_card.dat")
    if type(card) ~= "table" then return nil, "INVALID_ALBU_CARD" end
    if not card.card_id or not card.account_id then return nil, "INVALID_ALBU_CARD" end
    return card
end

function M.printHeader(title)
    term.clear()
    term.setCursorPos(1, 1)
    print("========================================")
    print("             ALBU BANKING")
    print("             " .. title)
    print("========================================")
end

function M.pause()
    print("")
    print("Press any key to continue...")
    os.pullEvent("key")
end

return M
