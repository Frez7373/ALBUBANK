-- ALBU BANK STORE TERMINAL
-- CC:Tweaked / Minecraft 1.16.5
--
-- First launch: insert the store owner's ALBU card and register this terminal.
-- After registration the terminal stores its TERM-XXXXXX ID locally.
-- Customers then insert their cards and pay through the central bank server.

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
    print("")
    print("ERROR: " .. tostring(err))
    bank.pause()
end

local function register()
    bank.printHeader("TERMINAL REGISTRATION")
    print("Insert the store owner's ALBU card.")
    print("")
    print("Waiting for card...")
    while true do
        local card, err = bank.readCardFromDrive()
        if card then
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

            saveConfig({
                terminal_id = result.id,
                terminal_name = result.name,
                owner_account_id = result.owner_account_id,
                owner_card_id = result.owner_card_id
            })

            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then drive.ejectDisk() end

            bank.printHeader("TERMINAL READY")
            print("Terminal ID : " .. result.id)
            print("Store       : " .. result.name)
            print("Owner       : " .. result.owner_account_id)
            print("")
            print("The terminal is now registered to the store owner.")
            bank.pause()
            return true
        end
        os.pullEvent("disk")
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

local function getCustomerCard()
    while true do
        local card, err = bank.readCardFromDrive()
        if card then return card end
        bank.printHeader("PAYMENT")
        print("Insert customer's ALBU card.")
        print("")
        print("Waiting for card...")
        local event = os.pullEvent()
        if event == "key" and event[2] == keys.q then return nil end
    end
end

local function makePayment(terminal)
    local card = getCustomerCard()
    if not card then return false end

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

    local ok, result, err = bank.request("payment", {
        terminal_id = terminal.id,
        card_id = card.card_id,
        pin = pin,
        amount = amount,
        description = description
    }, 8)

    if not ok then
        errorScreen(err)
        return true
    end

    bank.printHeader("PAYMENT APPROVED")
    print("Transaction : " .. result.transaction_id)
    print("Amount      : $" .. string.format("%.2f", result.amount))
    print("Customer    : " .. result.customer.owner_name)
    print("Remaining   : $" .. string.format("%.2f", result.customer.balance))
    print("Store       : " .. result.merchant.owner_name)
    print("")
    print("PAYMENT SUCCESSFUL")
    bank.pause()

    local drive = peripheral.find("drive")
    if drive and drive.isDiskPresent() then drive.ejectDisk() end
    return true
end

local function terminalMenu(terminal)
    while true do
        bank.printHeader("STORE TERMINAL")
        print("Store    : " .. terminal.name)
        print("Terminal : " .. terminal.id)
        print("Status   : " .. terminal.status)
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
            print("Terminal ID : " .. terminal.id)
            print("Store name  : " .. terminal.name)
            print("Owner acct  : " .. terminal.owner_account_id)
            print("Owner card  : " .. terminal.owner_card_id)
            print("Status      : " .. terminal.status)
            bank.pause()
        elseif choice == "3" then
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
        register()
        config = loadConfig()
    end
    if not config then return end

    while true do
        local terminal = getTerminal()
        if not terminal then
            bank.printHeader("TERMINAL OFFLINE")
            print("The terminal registration could not be found on the bank server.")
            print("")
            print("Press ENTER to try again or Q to exit.")
            local input = read()
            if input:lower() == "q" then return end
        else
            local keepGoing = terminalMenu(terminal)
            if not keepGoing then return end
            config = loadConfig()
            if not config then
                register()
                config = loadConfig()
                if not config then return end
            end
        end
    end
end

main()
