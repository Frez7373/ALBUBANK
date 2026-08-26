-- ALBU BANK INSTALLER
-- CC:Tweaked / Minecraft 1.16.5

local BASE="https://raw.githubusercontent.com/Frez7373/ALBUBANK/main/"
local items={
 ["1"]={name="ATM",files={{"atm.lua","/atm.lua"},{"lib/bank_client.lua","/lib/bank_client.lua"}}},
 ["2"]={name="Bank Computer",files={{"bank_computer.lua","/bank_computer.lua"},{"bank_computer_v2.lua","/bank_computer_v2.lua"},{"lib/bank_client.lua","/lib/bank_client.lua"}}},
 ["3"]={name="Bank Server",files={{"bank_server.lua","/bank_server.lua"},{"bank_server_v2.lua","/bank_server_v2.lua"}}},
 ["4"]={name="Store Terminal",files={{"store_terminal.lua","/store_terminal.lua"},{"store_terminal_v2.lua","/store_terminal_v2.lua"},{"lib/bank_client.lua","/lib/bank_client.lua"}}},
 ["5"]={name="Full Bank Package",files={{"bank_computer.lua","/bank_computer.lua"},{"bank_computer_v2.lua","/bank_computer_v2.lua"},{"bank_server.lua","/bank_server.lua"},{"bank_server_v2.lua","/bank_server_v2.lua"},{"atm.lua","/atm.lua"},{"store_terminal.lua","/store_terminal.lua"},{"store_terminal_v2.lua","/store_terminal_v2.lua"},{"lib/bank_client.lua","/lib/bank_client.lua"}}}
}

local function clear() term.clear() term.setCursorPos(1,1) end
local function header() clear(); print("========================================"); print("             ALBU BANK INSTALLER"); print("========================================"); print("") end
local function pause() print(""); print("Press any key to continue..."); os.pullEvent("key") end

local function download(remote,path)
 if not http then return false,"HTTP API is disabled" end
 local r,e=http.get(BASE..remote)
 if not r then return false,tostring(e or "HTTP error") end
 local data=r.readAll(); r.close()
 if not data or #data==0 then return false,"Empty download" end
 local dir=fs.getDir(path)
 if dir and dir~="" then fs.makeDir(dir) end
 local h=fs.open(path,"w")
 if not h then return false,"Cannot write "..path end
 h.write(data); h.close(); return true
end

local function install(item)
 header(); print("Installing: "..item.name); print("")
 for i,f in ipairs(item.files) do
  print(string.format("[%d/%d] %s",i,#item.files,f[1]))
  local ok,e=download(f[1],f[2])
  if not ok then print("ERROR: "..e); return false end
  print("OK -> "..f[2])
 end
 print(""); print("Installation complete.")
 return true
end

while true do
 header()
 print("1. ATM")
 print("2. Bank Computer")
 print("3. Bank Server")
 print("4. Store Terminal")
 print("5. Full Bank Package")
 print("6. Exit")
 print("")
 write("> ")
 local c=read()
 if items[c] then install(items[c]); pause()
 elseif c=="6" then clear(); print("Installer closed."); break
 else print("Invalid choice."); sleep(0.7) end
end
