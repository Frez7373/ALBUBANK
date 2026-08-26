-- ALBU BANK STORE TERMINAL V2
-- Only the current terminal owner can re-register/change its owner account.

local bank=dofile("/lib/bank_client.lua")
local CONFIG="/albu_terminal.dat"

local function save(v)
 local h=fs.open(CONFIG,"w") if not h then return false end
 h.write(textutils.serialize(v)) h.close() return true
end
local function load()
 if not fs.exists(CONFIG) then return nil end
 local h=fs.open(CONFIG,"r") if not h then return nil end
 local raw=h.readAll() h.close()
 local ok,v=pcall(textutils.unserialize,raw)
 if ok and type(v)=="table" then return v end
end

local function register(existing)
 bank.printHeader(existing and "CHANGE TERMINAL OWNER" or "TERMINAL REGISTRATION")
 if existing then
  print("Enter the CURRENT owner's card and PIN.")
 else
  print("Insert the store owner's ALBU card.")
 end
 local card,err=bank.waitForCard("Insert owner card.")
 if not card then print("ERROR: "..tostring(err)); bank.pause(); return false end
 local pin=bank.promptPin()
 write("Store name: ") local name=read()
 local action=existing and "re_register_terminal" or "register_terminal"
 local data
 if existing then data={terminal_id=existing.terminal_id,owner_card_id=card.card_id,owner_pin=pin,terminal_name=name}
 else data={card_id=card.card_id,pin=pin,terminal_name=name} end
 local ok,r,e=bank.request(action,data,8)
 if not ok then print("ERROR: "..tostring(e)); bank.pause(); return false end
 save({terminal_id=r.id,terminal_name=r.name,owner_account_id=r.owner_account_id,owner_card_id=r.owner_card_id})
 bank.ejectCard()
 bank.printHeader("TERMINAL READY")
 print("Terminal : "..r.id)
 print("Store    : "..r.name)
 print("Owner    : "..r.owner_account_id)
 print("")
 print("Only the current owner card + PIN can change this terminal.")
 bank.pause()
 return true
end

local function payment(t)
 local card,err=bank.waitForCard("Insert customer's ALBU card.")
 if not card then return false end
 local pin=bank.promptPin()
 write("Purchase amount: $") local amount=tonumber(read())
 write("Description: ") local desc=read()
 local ok,r,e=bank.request("payment",{terminal_id=t.id,card_id=card.card_id,pin=pin,amount=amount,description=desc},8)
 if not ok then print("ERROR: "..tostring(e)); bank.pause(); return true end
 bank.printHeader("PAYMENT APPROVED")
 print("Transaction : "..r.transaction_id)
 print("Amount      : $"..string.format("%.2f",r.amount))
 print("Customer    : "..r.customer.owner_name)
 print("Remaining   : $"..string.format("%.2f",r.customer.balance))
 print("") print("PAYMENT SUCCESSFUL")
 bank.ejectCard() bank.pause() return true
end

local function main()
 local cfg=load()
 if not cfg then if not register(nil) then return end cfg=load() end
 while true do
  local ok,t,e=bank.request("terminal_info",{terminal_id=cfg.terminal_id},5)
  if not ok then
   bank.printHeader("TERMINAL OFFLINE")
   print("Terminal not found on the bank server.")
   print("Press ENTER to retry or Q to exit.")
   local x=read() if x:lower()=="q" then return end
  else
   bank.printHeader("STORE TERMINAL")
   print("Store    : "..t.name)
   print("Terminal : "..t.id)
   print("Owner    : "..t.owner_account_id)
   print("")
   print("1. New payment")
   print("2. Terminal information")
   print("3. Change terminal owner")
   print("4. Exit")
   write("> ") local c=read()
   if c=="1" then payment(t)
   elseif c=="2" then bank.printHeader("TERMINAL INFORMATION"); print("ID: "..t.id); print("Store: "..t.name); print("Owner account: "..t.owner_account_id); bank.pause()
   elseif c=="3" then if register(t) then cfg=load() end
   elseif c=="4" then return end
  end
 end
end
main()
