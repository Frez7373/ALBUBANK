-- ALBU BANK STORE TERMINAL
-- CC:Tweaked / Minecraft 1.16.5
-- First launch registers this terminal to the store owner's ALBU card.

local bank = dofile("/lib/bank_client.lua")
local CONFIG = "/albu_terminal.dat"

local function saveConfig(value)
    local h = fs.open(CONFIG, "w")
    if not h then return false end
    h.write(textutils.serialize(value))
    h.close()
    return true
end

local function loadConfig()
    if not fs.exists(CONFIG) then return nil end
    local h = fs.open(CONFIG, "r")
    if not h then return nil end
    local raw = h.readAll()
    h.close()
    local ok, value = pcall(textutils.unserialize, raw)
    if ok and type(value) == "table" then return value end
    return nil
end

local function errorScreen(err)
    bank.printHeader("ERROR")
    print("ERROR: " .. tostring(err))
    bank.pause()
end

local function register()
    while true do
        local card, err = bank.waitForCard("Insert the STORE OWNER'S ALBU card.")
        if not card then
            if err == "CANCELLED" then return false end
            errorScreen(err)
        else
            bank.printHeader("TERMINAL REGISTRATION")
            print("Owner card: " .. tostring(card.card_id))
            print("")
            local pin = bank.promptPin()
            write("Store name: ")
            local storeName = read()
            if storeName == "" then storeName = "Store Terminal" end

            local ok, result, requestErr = bank.request("register_terminal", {
                card_id = card.card_id,
                pin = pin,
                terminal_name = storeName
            }, 8)

            if not ok then
                errorScreen(requestErr)
                return false
            end

            if not saveConfig({
                terminal_id = result.id,
                terminal_name = result.name,
                owner_account_id = result.owner_account_id,
                owner_card_id = result.owner_card_id
            }) then
                errorScreen("TERMINAL_CONFIG_WRITE_ERROR")
                return false
            end

            bank.ejectCard()
            bank.printHeader("TERMINAL READY")
            print("Terminal ID : " .. tostring(result.id))
            print("Store       : " .. tostring(result.name))
            print("Owner       : " .. tostring(result.owner_account_id))
            print("")
            print("Terminal registered successfully.")
            bank.pause()
            return true
        end
    end
end

local function getTerminal()
    local config = loadConfig()
    if not config then return nil end
    local ok, result = bank.request("terminal_info", {
        terminal_id = config.terminal_id
    }, 5)
    if not ok then return nil end
    return result
end

local function makePayment(terminal)
    local card, err = bank.waitForCard("Insert the CUSTOMER'S ALBU card.")
    if not card then
        if err ~= "CANCELLED" then errorScreen(err) end
        return false
    end

    bank.printHeader("PAYMENT")
    print("Card detected: " .. tostring(card.card_id))
    print("")
    local pin = bank.promptPin()

    write("Purchase amount: $")
    local amount = tonumber(read())
    if not amount or amount <= 0 then
        errorScreen("INVALID_AMOUNT")
        return true
    end

    write("Purchase description: ")
    local description = read()
    if description == "" then description = terminal.name end

    local ok, result, requestErr = bank.request("payment", {
        terminal_id = terminal.id,
        card_id = card.card_id,
        pin = pin,
        amount = amount,
        description = description
    }, 8)

    if not ok then
        errorScreen(requestErr)
        return true
    end

    bank.printHeader("PAYMENT APPROVED")
    print("Transaction : " .. tostring(result.transaction_id))
    print("Amount      : $" .. string.format("%.2f", tonumber(result.amount) or 0))
    print("Customer    : " .. tostring(result.customer.owner_name))
    print("Remaining   : $" .. string.format("%.2f", tonumber(result.customer.balance) or 0))
    print("Store       : " .. tostring(result.merchant.owner_name))
    print("")
    print("PAYMENT SUCCESSFUL")
    bank.pause()
    bank.ejectCard()
    return true
end

local function terminalMenu(terminal)
    while true do
        bank.printHeader("STORE TERMINAL")
        print("Store    : " .. tostring(terminal.name))
        print("Terminal : " .. tostring(terminal.id))
        print("Status   : " .. tostring(terminal.status))
        print("")
        print("1. New payment")
        print("2. Terminal information")
        print("3. Re-register terminal")
        print("4. Exit")
        print("")
        write("> ")
        local choice = read()

        if choice == "1" then
            makePayment(terminal)
        elseif choice == "2" then
            bank.printHeader("TERMINAL INFORMATION")
            print("Terminal ID : " .. tostring(terminal.id))
            print("Store name  : " .. tostring(terminal.name))
            print("Owner acct  : " .. tostring(terminal.owner_account_id))
            print("Owner card  : " .. tostring(terminal.owner_card_id))
            print("Status      : " .. tostring(terminal.status))
            bank.pause()
        elseif choice == "3" then
            bank.ejectCard()
            return register()
        elseif choice == "4" then
            return false
        else
            print("Invalid choice.")
            sleep(1)
        end
    end
end

local function main()
    math.randomseed((os.epoch("utc") + os.getComputerID()) % 2147483647)

    local config = loadConfig()
    if not config then
        if not register() then return end
        config = loadConfig()
    end

    while true do
        local terminal = getTerminal()
        if not terminal then
            bank.printHeader("TERMINAL OFFLINE")
            print("The terminal is not registered or the bank server is offline.")
            print("")
            print("Press ENTER to retry or Q to exit.")
            local input = read()
            if input:lower() == "q" then return end
        else
            local running = terminalMenu(terminal)
            if not running then return end
            config = loadConfig()
            if not config then
                if not register() then return end
            end
        end
    end
end

main()
