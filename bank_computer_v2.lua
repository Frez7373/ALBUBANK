-- ALBU BANK COMPUTER V2
-- CC:Tweaked / Minecraft 1.16.5

local bank = dofile("/lib/bank_client.lua")

local function req(action,data)
    local ok,result,err=bank.request(action,data,8)
    if not ok then print("ERROR: "..tostring(err)); bank.pause(); return nil end
    return result
end

local function writeCard(c)
    local drive=peripheral.find("drive")
    if not drive then print("ERROR: Disk Drive not found"); bank.pause(); return false end
    while not drive.isDiskPresent() do print("Insert blank card/floppy..."); os.pullEvent("disk") end
    local mount=drive.getMountPath()
    if not mount then print("ERROR: Card not mounted"); bank.pause(); return false end
    local h=fs.open(mount.."/albu_card.dat","w")
    if not h then print("ERROR: Cannot write card"); bank.pause(); return false end
    h.write(textutils.serialize({format=2,card_id=c.id,account_id=c.account_id,owner_name=c.owner_name,issuer="ALBU_BANK"}))
    h.close()
    print("Card written successfully.")
    return true
end

local function createAccount()
    bank.printHeader("CREATE ACCOUNT")
    write("Owner full name: ") local name=read()
    write("Initial balance: $") local balance=tonumber(read())
    write("Create 4-digit PIN: ") local pin=read("*")
    write("Confirm PIN: ") local pin2=read("*")
    if pin~=pin2 then print("PINs do not match."); bank.pause(); return end
    local r=req("create_account",{owner_name=name,initial_balance=balance,pin=pin})
    if not r then return end
    print("")
    print("ACCOUNT CREATED")
    print("Account : "..r.account.id)
    print("Card    : "..r.card.id)
    print("Owner   : "..r.card.owner_name)
    print("PIN     : "..r.card.pin)
    print("Balance : $"..string.format("%.2f",r.account.balance))
    print("")
    print("Insert the card/floppy to write card data.")
    writeCard(r.card)
    bank.pause()
end

local function lookup()
    bank.printHeader("ACCOUNT LOOKUP")
    write("Account ID: ") local id=read()
    local r=req("account_lookup",{account_id=id}) if not r then return end
    print("Owner   : "..r.owner_name)
    print("Card    : "..r.card_id)
    print("Balance : $"..string.format("%.2f",r.balance))
    print("Status  : "..r.status)
    bank.pause()
end

local function money(action)
    bank.printHeader(action=="deposit" and "DEPOSIT" or "WITHDRAW")
    write("Account ID: ") local id=read()
    write("Amount: $") local amount=tonumber(read())
    write("Description: ") local desc=read()
    req(action,{account_id=id,amount=amount,description=desc})
    bank.pause()
end

local function cardStatus()
    bank.printHeader("CARD MANAGEMENT")
    write("Card ID: ") local id=read()
    write("Status (active/blocked): ") local status=read()
    req("set_card_status",{card_id=id,status=status})
    bank.pause()
end

local function checkCard()
    local c,e=bank.readCardFromDrive()
    if not c then print("ERROR: "..tostring(e)); bank.pause(); return end
    local pin=bank.promptPin()
    local r=req("card_info",{card_id=c.card_id,pin=pin}) if not r then return end
    bank.printHeader("CARD INFORMATION")
    print("Owner      : "..r.owner_name)
    print("Card ID    : "..r.card_id)
    print("Account ID : "..r.account_id)
    print("Balance    : $"..string.format("%.2f",r.balance))
    print("Card       : "..r.card_status)
    print("Account    : "..r.account_status)
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
        write("> ") local c=read()
        if c=="1" then createAccount()
        elseif c=="2" then lookup()
        elseif c=="3" then money("deposit")
        elseif c=="4" then money("withdraw")
        elseif c=="5" then cardStatus()
        elseif c=="6" then checkCard()
        elseif c=="7" then return
        else sleep(0.5) end
    end
end

parallel.waitForAny(function() shell.run("/bank_server.lua") end,main)
