-- ALBU BANK INSTALLER
-- CC:Tweaked / Minecraft 1.16.5
-- Installs exactly the selected component.

local BASE = "https://raw.githubusercontent.com/Frez7373/ALBUBANK/main/"

local components = {
    ["1"] = {
        name = "ATM",
        files = {
            {remote = "atm.lua", localPath = "/atm.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["2"] = {
        name = "Bank Computer",
        files = {
            {remote = "bank_computer.lua", localPath = "/bank_computer.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["3"] = {
        name = "Bank Server",
        files = {
            {remote = "bank_server.lua", localPath = "/bank_server.lua"}
        }
    },
    ["4"] = {
        name = "Store Terminal",
        files = {
            {remote = "store_terminal.lua", localPath = "/store_terminal.lua"},
            {remote = "store_terminal_v2.lua", localPath = "/store_terminal_v2.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["5"] = {
        name = "Full Bank Package",
        files = {
            {remote = "bank_computer.lua", localPath = "/bank_computer.lua"},
            {remote = "bank_server.lua", localPath = "/bank_server.lua"},
            {remote = "atm.lua", localPath = "/atm.lua"},
            {remote = "store_terminal.lua", localPath = "/store_terminal.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    }
}

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function header(title)
    clear()
    print("========================================")
    print("             ALBU BANK")
    print("              INSTALLER")
    print("========================================")
    print("")
    if title then print(title) end
    print("")
end

local function pause()
    print("")
    print("Press any key to continue...")
    os.pullEvent("key")
end

local function download(remote, localPath)
    if not http then
        return false, "HTTP API is disabled"
    end

    local url = BASE .. remote .. "?v=" .. tostring(os.epoch("utc"))
    local response, err = http.get(url)
    if not response then
        return false, "Download failed: " .. tostring(err or "HTTP error")
    end

    local content = response.readAll()
    response.close()

    if not content or content == "" then
        return false, "Downloaded file is empty"
    end

    local dir = fs.getDir(localPath)
    if dir and dir ~= "" then
        fs.makeDir(dir)
    end

    local file = fs.open(localPath, "w")
    if not file then
        return false, "Cannot write " .. localPath
    end

    file.write(content)
    file.close()
    return true
end

local function cleanupOldFiles()
    local old = {
        "/bank_computer_v2.lua",
        "/bank_server_v2.lua",
        "/store_terminal_v2.lua"
    }
    for _, path in ipairs(old) do
        if fs.exists(path) then
            fs.delete(path)
        end
    end
end

local function install(component)
    header("Installing " .. component.name)
    cleanupOldFiles()

    for i, item in ipairs(component.files) do
        print(string.format("[%d/%d] %s", i, #component.files, item.remote))
        local ok, err = download(item.remote, item.localPath)
        if not ok then
            print("ERROR: " .. tostring(err))
            return false
        end
        print("OK -> " .. item.localPath)
    end

    print("")
    print("Installation complete.")
    return true
end

local function main()
    while true do
        header("Select what you want to install")
        print("1. ATM")
        print("2. Bank Computer")
        print("3. Bank Server")
        print("4. Store Terminal")
        print("5. Full Bank Package")
        print("6. Exit")
        print("")
        write("> ")

        local choice = read()
        local component = components[choice]

        if component then
            install(component)
            pause()
        elseif choice == "6" then
            clear()
            print("ALBU BANK Installer closed.")
            return
        else
            print("Invalid choice.")
            sleep(0.8)
        end
    end
end

main()
