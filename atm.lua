-- ALBU BANK ATM
-- CC:Tweaked / Minecraft 1.16.5
-- Insert an ALBU bank card (disk) to view account information, balance and transactions.

local bank = dofile("/lib/bank_client.lua")

local function showError(err)
    print("")
    print("ERROR: " .. tostring(err))
    bank.pause()
end

local function waitForCard()
    while true do
        local card, err = bank.readCardFromDrive()
        if card then return card end
        bank.printHeader("INSERT CARD")
        print("Insert your ALBU bank card into the disk drive.")
        print("")
        print("Waiting for card...")
        local event = os.pullEvent()
        if event == "disk" then
            -- Retry immediately.
        elseif event == "key" then
            local key = event[2]
            if key == keys.q then return nil end
        end
    end
end

local function cardSession(card)
    local pin = bank.promptPin()
    local ok, info, err = bank.request("card_info", {
        card_id = card.card_id,
        pin = pin
    })
    if not ok then
        showError(err)
        return true
    end

    while true do
        bank.printHeader("ATM")
        print("CARD  : " .. info.card_id)
        print("OWNER : " .. info.owner_name)
        print("")
        print("1. Card information")
        print("2. Balance")
        print("3. Transactions")
        print("4. Eject card")
        print("")
        write("> ")
        local choice = read()

        if choice == "1" then
            bank.printHeader("CARD INFORMATION")
            print("Owner          : " .. info.owner_name)
            print("Card ID        : " .. info.card_id)
            print("Account ID     : " .. info.account_id)
            print("Card status    : " .. info.card_status)
            print("Account status : " .. info.account_status)
            bank.pause()

        elseif choice == "2" then
            local balanceOk, account, balanceErr = bank.request("balance", {
                card_id = card.card_id,
                pin = pin
            })
            if not balanceOk then
                showError(balanceErr)
            else
                bank.printHeader("BALANCE")
                print("Account : " .. account.id)
                print("")
                print(string.format("BALANCE: %.2f %s", account.balance, account.currency))
                bank.pause()
                info.balance = account.balance
            end

        elseif choice == "3" then
            local txOk, txList, txErr = bank.request("transactions", {
                card_id = card.card_id,
                pin = pin,
                limit = 12
            })
            if not txOk then
                showError(txErr)
            else
                bank.printHeader("TRANSACTIONS")
                if #txList == 0 then
                    print("No transactions.")
                else
                    for _, tx in ipairs(txList) do
                        local amount = tonumber(tx.amount) or 0
                        print(string.format("%s  %+.2f  %s", tostring(tx.type), amount, tostring(tx.currency or "USD")))
                        print("  " .. tostring(tx.description or ""))
                    end
                end
                bank.pause()
            end

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
    while true do
        local card = waitForCard()
        if not card then return end
        local keepRunning = cardSession(card)
        if not keepRunning then
            local drive = peripheral.find("drive")
            if drive and drive.isDiskPresent() then
                drive.ejectDisk()
            end
        end
    end
end

main()
