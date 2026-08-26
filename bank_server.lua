-- ALBU BANK SERVER ENTRYPOINT
-- CC:Tweaked / Minecraft 1.16.5
-- The current implementation is kept in bank_server_v2.lua.
if not fs.exists("/bank_server_v2.lua") then
    error("bank_server_v2.lua not found. Re-run the ALBU BANK installer.")
end
shell.run("/bank_server_v2.lua")
