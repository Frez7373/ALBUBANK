-- ALBU BANK COMPUTER
-- CC:Tweaked / Minecraft 1.16.5
-- Central bank operator computer.

local bank = dofile("/lib/bank_client.lua")

local function request(action, data)
    local ok, result, err = bank.request(action, data, 8)
    if not ok then
        print("ERROR: " .. tostring(err))
        bank.pause()
        return nil
    end
    return result
end

local function writeCard(card)
    local drive = peripheral.find("drive")
    if not drive then
        print("ERROR: Disk Drive not found")
        bank.pause()
        return false
    end

    while not drive.isDiskPresent() do
        bank.printHeader("INSERT CARD")
        print("Insert a blank floppy/card into the disk drive.")
        print("Waiting for card...")
        local event = os.pullEvent()
        if event == "key" then
            -- Ignore key presses while waiting.
        end
    end

    local mount = drive.getMountPath()
    if not mount then
        print("ERROR: Card mount unavailable")
        bank.pause()
        return false
    end

    drive.setDiskLabel("ATM CARD CCI")

    local h = fs.open(mount .. "/albu_card.dat", "w")
    if not h then
        print("ERROR: Cannot write card")
        bank.pause()
        return false
    end

    h.write(textutils.serialize({
        format = 2,
        card_id = card.id,
        account_id = card.account_id,
        owner_name = card.owner_name,
        issuer = "ALBU_BANK"
    }))
    h.close()

    return true
end

local function createAccount()
    bank.printHeader("CREATE ACCOUNT")

    write("Owner full name: ")
    local name = read()
    if name == "" then
        print("Owner name cannot be empty.")
        bank.pause()
        return
    end

    write("Initial balance: $")
    local balance = tonumber(read())
    if balance == nil or balance < 0 then
        print("Invalid initial balance.")
        bank.pause()
        return
    end

    write("Create 4-digit PIN: ")
    local pin = read("*")
    write("Confirm PIN: ")
    local pin2 = read("*")

    if pin ~= pin2 then
        print("PINs do not match.")
        bank.pause()
        return
    end

    local result = request("create_account", {
        owner_name = name,
        initial_balance = balance,
        pin = pin
    })
    if not result then return end

    bank.printHeader("ACCOUNT CREATED")
    print("Account : " .. result.account.id)
    print("Card    : " .. result.card.id)
    print("Owner   : " .. result.card.owner_name)
    print("PIN     : " .. result.card.pin)
    print("Balance : $" .. string.format("%.2f", result.account.balance))
    print("")
    print("Insert the card/floppy to write card data.")

    if writeCard(result.card) then
        print("Card written successfully.")
    end

    bank.pause()
end

local function accountLookup()
    bank.printHeader("ACCOUNT LOOKUP")
    write("Account ID: ")
    local id = read()

    local result = request("account_lookup", {
        account_id = id
    })
    if not result then return end

    print("Account : " .. result.id)
    print("Owner   : " .. result.owner_name)
    print("Card    : " .. result.card_id)
    print("Balance : $" .. string.format("%.2f", result.balance))
    print("Status  : " .. result.status)
    bank.pause()
end

local function changeMoney(action)
    bank.printHeader(action == "deposit" and "DEPOSIT" or "WITHDRAW")

    write("Account ID: ")
    local id = read()
    write("Amount: $")
    local amount = tonumber(read())
    write("Description: ")
    local description = read()

    local result = request(action, {
        account_id = id,
        amount = amount,
        description = description
    })
    if not result then return end

    print("")
    print("Operation successful.")
    print("Account : " .. result.id)
    print("Balance : $" .. string.format("%.2f", result.balance))
    bank.pause()
end

local function cardManagement()
    bank.printHeader("CARD MANAGEMENT")
    write("Card ID: ")
    local id = read()
    write("Status (active/blocked): ")
    local status = read()

    local result = request("set_card_status", {
        card_id = id,
        status = status
    })
    if not result then return end

    print("")
    print("Card " .. result.card_id .. " is now " .. result.status)
    bank.pause()
end

local function checkCard()
    local card, err = bank.waitForCard("Insert an ALBU card to inspect it.")
    if not card then
        print("ERROR: " .. tostring(err))
        bank.pause()
        return
    end

    local pin = bank.promptPin()
    local result = request("card_info", {
        card_id = card.card_id,
        pin = pin
    })
    if not result then return end

    bank.printHeader("CARD INFORMATION")
    print("Owner      : " .. result.owner_name)
    print("Card ID    : " .. result.card_id)
    print("Account ID : " .. result.account_id)
    print("Balance    : $" .. string.format("%.2f", result.balance))
    print("Card       : " .. result.card_status)
    print("Account    : " .. result.account_status)
    bank.pause()
end

local function main()
    while true do
        bank.printHeader("BANK OPERATOR")
        print("1. Create account + card")
        print("2. Account lookup")
        print("3. Deposit money")
        print("4. Withdraw money")
        print("5. Card management")
        print("6. Check card")
        print("7. Exit")
        print("")
        write("> ")
        local choice = read()

        if choice == "1" then
            createAccount()
        elseif choice == "2" then
            accountLookup()
        elseif choice == "3" then
            changeMoney("deposit")
        elseif choice == "4" then
            changeMoney("withdraw")
        elseif choice == "5" then
            cardManagement()
        elseif choice == "6" then
            checkCard()
        elseif choice == "7" then
            return
        else
            print("Invalid choice.")
            sleep(0.5)
        end
    end
end

main()
