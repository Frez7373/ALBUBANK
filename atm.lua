-- ALBU BANK ATM
-- CC:Tweaked / Minecraft 1.16.5
-- Insert an ALBU bank card to view account information, balance and transactions.

local bank = dofile("/lib/bank_client.lua")

local function showError(err)
    bank.printHeader("ERROR")
    print("ERROR: " .. tostring(err))
    bank.pause()
end

local function cardSession(card)
    bank.printHeader("AUTHENTICATION")
    print("CARD: " .. tostring(card.card_id))
    print("")
    local pin = bank.promptPin()

    local ok, info, err = bank.request("card_info", {
        card_id = card.card_id,
        pin = pin
    }, 8)

    if not ok then
        showError(err)
        bank.ejectCard()
        return false
    end

    while true do
        if not peripheral.find("drive").isDiskPresent() then
            return false
        end

        bank.printHeader("ATM")
        print("CARD  : " .. tostring(info.card_id))
        print("OWNER : " .. tostring(info.owner_name))
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
            print("Owner          : " .. tostring(info.owner_name))
            print("Card ID        : " .. tostring(info.card_id))
            print("Account ID     : " .. tostring(info.account_id))
            print("Card status    : " .. tostring(info.card_status))
            print("Account status : " .. tostring(info.account_status))
            bank.pause()

        elseif choice == "2" then
            local balanceOk, account, balanceErr = bank.request("balance", {
                card_id = card.card_id,
                pin = pin
            }, 8)
            if not balanceOk then
                showError(balanceErr)
            else
                bank.printHeader("BALANCE")
                print("Account : " .. tostring(account.id))
                print("")
                print(string.format("BALANCE: %.2f %s", tonumber(account.balance) or 0, tostring(account.currency or "USD")))
                bank.pause()
                info.balance = account.balance
            end

        elseif choice == "3" then
            local txOk, txList, txErr = bank.request("transactions", {
                card_id = card.card_id,
                pin = pin,
                limit = 12
            }, 8)
            if not txOk then
                showError(txErr)
            else
                bank.printHeader("TRANSACTIONS")
                if #txList == 0 then
                    print("No transactions.")
                else
                    for _, tx in ipairs(txList) do
                        local amount = tonumber(tx.amount) or 0
                        print(string.format("%s  %+.2f %s", tostring(tx.type), amount, tostring(tx.currency or "USD")))
                        print("  " .. tostring(tx.description or ""))
                    end
                end
                bank.pause()
            end

        elseif choice == "4" then
            bank.ejectCard()
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
        local card, err = bank.waitForCard("Insert your ALBU bank card into the disk drive.")
        if not card then
            if err == "CANCELLED" then
                return
            end
            showError(err)
            sleep(1)
        else
            cardSession(card)
        end
    end
end

main()
