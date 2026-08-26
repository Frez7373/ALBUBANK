-- ALBU BANK COMPUTER
-- CC:Tweaked / Minecraft 1.16.5
--
-- Run this on the central bank computer.
-- It runs the central server in parallel and provides the bank operator UI.

local CLIENT = dofile("/lib/bank_client.lua")
local SERVER = "/bank_server.lua"

local function runServer()
    if not fs.exists(SERVER) then
        print("ERROR: bank_server.lua not found")
        return
    end
    shell.run(SERVER)
end

local function request(action, data)
    local ok, result, err = CLIENT.request(action, data, 8)
    if not ok then
        print("ERROR: " .. tostring(err))
        CLIENT.pause()
        return nil
    end
    return result
end

local function cardFileWrite(card)
    local drive = peripheral.find("drive")
    if not drive then
        print("ERROR: Disk Drive not found")
        CLIENT.pause()
        return false
    end
    if not drive.isDiskPresent() then
        print("Insert a blank floppy/card into the disk drive.")
        print("Waiting for disk...")
        os.pullEvent("disk")
    end
    local mount = drive.getMountPath()
    if not mount then
        print("ERROR: Card mount unavailable")
        CLIENT.pause()
        return false
    end

    local h = fs.open(mount .. "/albu_card.dat", "w")
    if not h then
        print("ERROR: Cannot write card")
        CLIENT.pause()
        return false
    end
    h.write(textutils.serialize({
        format = 1,
        card_id = card.id,
        account_id = card.account_id,
        owner_name = card.owner_name,
        issuer = "ALBU_BANK"
    }))
    h.close()
    return true
end

local function createAccount()
    CLIENT.printHeader("CREATE ACCOUNT")
    write("Owner full name: ")
    local owner = read()
    write("Initial balance: $")
    local balance = tonumber(read()) or 0
    if owner == "" then
        print("Owner name cannot be empty.")
        CLIENT.pause()
        return
    end

    local result = request("create_account", {
        owner_name = owner,
        initial_balance = balance
    })
    if not result then return end

    print("")
    print("ACCOUNT CREATED")
    print("Account : " .. result.account.id)
    print("Card    : " .. result.card.id)
    print("Owner   : " .. result.card.owner_name)
    print("PIN     : " .. result.card.pin)
    print("Balance : $" .. string.format("%.2f", result.account.balance))
    print("")
    print("Insert the card/disc to write the card data.")
    if cardFileWrite(result.card) then
        print("Card written successfully.")
    end
    CLIENT.pause()
end

local function lookupAccount()
    CLIENT.printHeader("ACCOUNT LOOKUP")
    write("Account ID: ")
    local id = read()
    local result = request("account_lookup", {account_id = id})
    if not result then return end
    print("")
    print("Account ID : " .. result.id)
    print("Owner      : " .. result.owner_name)
    print("Card       : " .. result.card_id)
    print("Balance    : $" .. string.format("%.2f", result.balance))
    print("Status     : " .. result.status)
    CLIENT.pause()
end

local function changeMoney(kind)
    CLIENT.printHeader(kind == "deposit" and "DEPOSIT" or "WITHDRAW")
    write("Account ID: ")
    local id = read()
    write("Amount: $")
    local amount = tonumber(read())
    write("Description: ")
    local desc = read()
    local result = request(kind, {
        account_id = id,
        amount = amount,
        description = desc
    })
    if not result then return end
    print("")
    print("Operation successful.")
    print("Account : " .. result.id)
    print("Balance : $" .. string.format("%.2f", result.balance))
    CLIENT.pause()
end

local function cardManagement()
    CLIENT.printHeader("CARD MANAGEMENT")
    write("Card ID: ")
    local cardId = read()
    write("New status (active/blocked): ")
    local status = read()
    local result = request("set_card_status", {
        card_id = cardId,
        status = status
    })
    if result then
        print("")
        print("Card " .. result.card_id .. " is now " .. result.status)
    end
    CLIENT.pause()
end

local function inspectCard()
    CLIENT.printHeader("CARD CHECK")
    write("Insert card into disk drive, then press ENTER.")
    read()
    local card, err = CLIENT.readCardFromDrive()
    if not card then
        print("ERROR: " .. tostring(err))
        CLIENT.pause()
        return
    end
    local pin = CLIENT.promptPin()
    local result = request("card_info", {card_id = card.card_id, pin = pin})
    if not result then return end
    print("")
    print("Owner      : " .. result.owner_name)
    print("Card ID    : " .. result.card_id)
    print("Account ID : " .. result.account_id)
    print("Balance    : $" .. string.format("%.2f", result.balance))
    print("Card       : " .. result.card_status)
    print("Account    : " .. result.account_status)
    CLIENT.pause()
end

local function mainMenu()
    while true do
        CLIENT.printHeader("BANK OPERATOR")
        print("1. Create new account + card")
        print("2. Account lookup")
        print("3. Deposit money")
        print("4. Withdraw money")
        print("5. Card management")
        print("6. Check card")
        print("7. Exit bank computer")
        print("")
        write("> ")
        local choice = read()
        if choice == "1" then
            createAccount()
        elseif choice == "2" then
            lookupAccount()
        elseif choice == "3" then
            changeMoney("deposit")
        elseif choice == "4" then
            changeMoney("withdraw")
        elseif choice == "5" then
            cardManagement()
        elseif choice == "6" then
            inspectCard()
        elseif choice == "7" then
            return
        else
            print("Invalid choice.")
            sleep(1)
        end
    end
end

parallel.waitForAny(runServer, mainMenu)
