-- ALBU BANK STORE TERMINAL ENTRYPOINT
-- CC:Tweaked / Minecraft 1.16.5
if not fs.exists("/store_terminal_v2.lua") then
    error("store_terminal_v2.lua not found. Re-run the ALBU BANK installer.")
end
shell.run("/store_terminal_v2.lua")
