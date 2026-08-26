-- ALBU BANK INSTALLER
-- CC:Tweaked / Minecraft 1.16.5
-- Downloads selected components from the official ALBU BANK GitHub repository.

local BASE_URL = "https://raw.githubusercontent.com/Frez7373/ALBUBANK/main/"
local LIB_URL = BASE_URL .. "lib/bank_client.lua"

local components = {
    ["1"] = {
        name = "Central Bank Computer",
        files = {
            {remote = "bank_computer.lua", localPath = "/bank_computer.lua"},
            {remote = "bank_server.lua", localPath = "/bank_server.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["2"] = {
        name = "ATM",
        files = {
            {remote = "atm.lua", localPath = "/atm.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["3"] = {
        name = "Store Terminal",
        files = {
            {remote = "store_terminal.lua", localPath = "/store_terminal.lua"},
            {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
        }
    },
    ["4"] = {
        name = "Bank Server only",
        files = {
            {remote = "bank_server.lua", localPath = "/bank_server.lua"}
        }
    },
    ["5"] = {
        name = "Everything",
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
    print("               INSTALLER")
    print("========================================")
    print(title or "")
    print("")
end

local function pause()
    print("")
    print("Press any key to continue...")
    os.pullEvent("key")
end

local function httpAvailable()
    if not http then
        return false, "HTTP API is unavailable. Enable HTTP in the CC:Tweaked computer configuration."
    end
    return true
end

local function download(url, path)
    local response, err = http.get(url)
    if not response then
        return false, "Download failed: " .. tostring(err or "unknown HTTP error")
    end

    local content = response.readAll()
    response.close()

    if not content or content == "" then
        return false, "Downloaded file is empty."
    end

    local parent = fs.getDir(path)
    if parent and parent ~= "" then
        fs.makeDir(parent)
    end

    local handle = fs.open(path, "w")
    if not handle then
        return false, "Cannot write: " .. path
    end

    handle.write(content)
    handle.close()
    return true
end

local function install(component)
    local okHttp, httpError = httpAvailable()
    if not okHttp then
        print("ERROR: " .. httpError)
        return false
    end

    header("Installing: " .. component.name)

    local total = #component.files
    for index, file in ipairs(component.files) do
        print(string.format("[%d/%d] %s", index, total, file.remote))
        local ok, err = download(BASE_URL .. file.remote, file.localPath)
        if not ok then
            print("  ERROR: " .. tostring(err))
            return false
        end
        print("  Installed -> " .. file.localPath)
    end

    print("")
    print("Installation completed successfully.")
    return true
end

local function installCustom()
    header("Custom component")
    print("1. bank_computer.lua")
    print("2. bank_server.lua")
    print("3. atm.lua")
    print("4. store_terminal.lua")
    print("5. shared library")
    print("6. back")
    print("")
    write("> ")
    local choice = read()

    local file
    if choice == "1" then
        file = {remote = "bank_computer.lua", localPath = "/bank_computer.lua"}
    elseif choice == "2" then
        file = {remote = "bank_server.lua", localPath = "/bank_server.lua"}
    elseif choice == "3" then
        file = {remote = "atm.lua", localPath = "/atm.lua"}
    elseif choice == "4" then
        file = {remote = "store_terminal.lua", localPath = "/store_terminal.lua"}
    elseif choice == "5" then
        file = {remote = "lib/bank_client.lua", localPath = "/lib/bank_client.lua"}
    else
        return
    end

    local okHttp, httpError = httpAvailable()
    if not okHttp then
        print("ERROR: " .. httpError)
        pause()
        return
    end

    header("Installing: " .. file.remote)
    local ok, err = download(BASE_URL .. file.remote, file.localPath)
    if ok then
        print("Installed -> " .. file.localPath)
    else
        print("ERROR: " .. tostring(err))
    end
    pause()
end

local function mainMenu()
    while true do
        header("Select what to install")
        print("1. Central Bank Computer")
        print("2. ATM")
        print("3. Store Terminal")
        print("4. Bank Server only")
        print("5. Everything")
        print("6. Custom component")
        print("7. Exit")
        print("")
        write("> ")
        local choice = read()

        if components[choice] then
            local success = install(components[choice])
            pause()
        elseif choice == "6" then
            installCustom()
        elseif choice == "7" then
            clear()
            print("ALBU BANK Installer closed.")
            return
        else
            print("Invalid choice.")
            sleep(1)
        end
    end
end

math.randomseed((os.epoch("utc") + os.getComputerID()) % 2147483647)
mainMenu()
