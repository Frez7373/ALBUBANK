-- ALBU BANK CLIENT LIBRARY
-- Shared by ATM, Store Terminal and Bank Computer.
-- CC:Tweaked / Minecraft 1.16.5

local M = {}

M.PORT = 4200
M.NETWORK_NAME = "ALBU_BANK"

local function getModem()
    local modem = peripheral.find("modem")
    if not modem then
        error("ERROR: Modem not found")
    end
    return modem
end

local function makeRequestId()
    return string.format("REQ-%d-%04d", os.epoch("utc"), math.random(0, 9999))
end

function M.request(action, data, timeout)
    local modem = getModem()
    timeout = tonumber(timeout) or 8
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

    local timerId = os.startTimer(timeout)

    while true do
        local event, p1, p2, p3, p4 = os.pullEvent()

        if event == "modem_message" then
            local channel = p2
            local response = p4
            if channel == replyChannel and type(response) == "table" then
                if response.type == "response" and response.request_id == requestId then
                    modem.close(replyChannel)
                    return response.ok, response.data, response.error
                end
            end
        elseif event == "timer" and p1 == timerId then
            modem.close(replyChannel)
            return false, nil, "BANK_SERVER_TIMEOUT"
        end
    end
end

function M.promptPin()
    term.write("PIN: ")
    return read("*")
end

local function readTable(path)
    if not fs.exists(path) then return nil end
    local h = fs.open(path, "r")
    if not h then return nil end
    local raw = h.readAll()
    h.close()
    local ok, value = pcall(textutils.unserialize, raw)
    if ok and type(value) == "table" then
        return value
    end
    return nil
end

function M.readCardFromDrive()
    local drive = peripheral.find("drive")
    if not drive then return nil, "DISK_DRIVE_NOT_FOUND" end
    if not drive.isDiskPresent() then return nil, "CARD_NOT_INSERTED" end

    local mount = drive.getMountPath()
    if not mount then return nil, "CARD_NOT_MOUNTED" end

    local card = readTable(mount .. "/albu_card.dat")
    if not card then return nil, "INVALID_ALBU_CARD" end
    if not card.card_id or not card.account_id then
        return nil, "INVALID_ALBU_CARD"
    end

    return card
end

-- Continuously watches the disk drive. A newly inserted card is detected
-- immediately and does not require restarting the ATM or terminal.
function M.waitForCard(message)
    if not peripheral.find("drive") then
        return nil, "DISK_DRIVE_NOT_FOUND"
    end

    while true do
        local card = M.readCardFromDrive()
        if card then
            return card
        end

        term.clear()
        term.setCursorPos(1, 1)
        print("========================================")
        print("             ALBU BANKING")
        print("========================================")
        print(message or "Insert an ALBU bank card.")
        print("")
        print("Waiting for card...")
        print("Press Q to cancel.")

        local timerId = os.startTimer(0.5)
        while true do
            local event, p1 = os.pullEvent()
            if event == "disk" then
                break
            elseif event == "timer" and p1 == timerId then
                break
            elseif event == "key" and p1 == keys.q then
                return nil, "CANCELLED"
            end
        end
    end
end

function M.ejectCard()
    local drive = peripheral.find("drive")
    if drive and drive.isDiskPresent() then
        drive.ejectDisk()
    end
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
