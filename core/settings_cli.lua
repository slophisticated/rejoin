local Logger = require("core.logger")
local Config = require("core.config")

local CLI = {}

local function prompt(msg)
    io.write(msg)
    io.flush()
    return io.read()
end

local function printSettings(conf)
    print("Current Settings:")
    print("  monitorInterval = " .. tostring(conf.monitorInterval))
    print("  recoveryDelay = " .. tostring(conf.recoveryDelay))
    print("  recoveryRetries = " .. tostring(conf.recoveryRetries))
    print("  checkTimeout = " .. tostring(conf.checkTimeout))
    print("  debug = " .. tostring(conf.debug))
    print("  autoExecute = " .. tostring(conf.autoExecute))
    print("  autoExecuteDeployPath = " .. tostring(conf.autoExecuteDeployPath))
    print("  logPath = " .. tostring(conf.logPath))
    print("  clonePackagePrefix = " .. tostring(conf.clonePackagePrefix or ""))
    print("  freezeTimeout = " .. tostring(conf.freezeTimeout))
    print("  gracePeriod = " .. tostring(conf.gracePeriod))
    print("  anrCheckEnabled = " .. tostring(conf.anrCheckEnabled and true or false))
end

function CLI.run()
    local conf = Config.get() or {}
    conf.monitorInterval = conf.monitorInterval or 5
    conf.recoveryDelay = conf.recoveryDelay or 3
    conf.recoveryRetries = conf.recoveryRetries or 3
    conf.checkTimeout = conf.checkTimeout or 15
    conf.debug = conf.debug == nil and true or conf.debug
    conf.autoExecute = conf.autoExecute or ""
    conf.autoExecuteDeployPath = conf.autoExecuteDeployPath or "data/autoexecute"
    conf.logPath = conf.logPath or "data/rejoin.log"
    conf.clonePackagePrefix = conf.clonePackagePrefix or ""
    conf.freezeTimeout = conf.freezeTimeout or 300
    conf.gracePeriod = conf.gracePeriod or 30
    conf.anrCheckEnabled = conf.anrCheckEnabled ~= false

    while true do
        print('\nSettings Menu:\n  1) View settings\n  2) Edit monitorInterval\n  3) Edit recoveryDelay\n  4) Edit recoveryRetries\n  5) Edit checkTimeout\n  6) Toggle debug\n  7) Edit autoExecute global path\n  8) Edit autoExecute deploy path\n  9) Edit logPath\n 10) Edit clonePackagePrefix\n 11) Edit freezeTimeout\n 12) Edit gracePeriod\n 13) Toggle anrCheckEnabled\n 14) Save and Exit\n 15) Exit without saving\n')
        local choice = prompt("Choose: ") or ""
        choice = choice:match("^%s*(.-)%s*$")
        if choice == "1" then
            printSettings(conf)
        elseif choice == "2" then
            local v = prompt("monitorInterval (seconds): [" .. tostring(conf.monitorInterval) .. "] ")
            local n = tonumber(v)
            if n then conf.monitorInterval = n else print("Invalid number") end
        elseif choice == "3" then
            local v = prompt("recoveryDelay (seconds): [" .. tostring(conf.recoveryDelay) .. "] ")
            local n = tonumber(v)
            if n then conf.recoveryDelay = n else print("Invalid number") end
        elseif choice == "4" then
            local v = prompt("recoveryRetries: [" .. tostring(conf.recoveryRetries) .. "] ")
            local n = tonumber(v)
            if n then conf.recoveryRetries = n else print("Invalid number") end
        elseif choice == "5" then
            local v = prompt("checkTimeout (seconds): [" .. tostring(conf.checkTimeout) .. "] ")
            local n = tonumber(v)
            if n then conf.checkTimeout = n else print("Invalid number") end
        elseif choice == "6" then
            conf.debug = not conf.debug
            print("debug = " .. tostring(conf.debug))
        elseif choice == "7" then
            local v = prompt("autoExecute global path (script): [" .. tostring(conf.autoExecute) .. "] ")
            if v and v ~= "" then conf.autoExecute = v end
        elseif choice == "8" then
            local v = prompt("autoExecute deploy path: [" .. tostring(conf.autoExecuteDeployPath) .. "] ")
            if v and v ~= "" then conf.autoExecuteDeployPath = v end
        elseif choice == "9" then
            local v = prompt("logPath: [" .. tostring(conf.logPath) .. "] ")
            if v and v ~= "" then conf.logPath = v end
        elseif choice == "10" then
            local v = prompt("clonePackagePrefix (empty to disable): [" .. tostring(conf.clonePackagePrefix) .. "] ")
            if v and v ~= "" then conf.clonePackagePrefix = v end
        elseif choice == "11" then
            local v = prompt("freezeTimeout (seconds before relaunch): [" .. tostring(conf.freezeTimeout) .. "] ")
            local n = tonumber(v)
            if n and n > 0 then conf.freezeTimeout = n else print("Invalid number") end
        elseif choice == "12" then
            local v = prompt("gracePeriod (seconds after launch): [" .. tostring(conf.gracePeriod) .. "] ")
            local n = tonumber(v)
            if n and n > 0 then conf.gracePeriod = n else print("Invalid number") end
        elseif choice == "13" then
            conf.anrCheckEnabled = not (conf.anrCheckEnabled and true or false)
            print("anrCheckEnabled = " .. tostring(conf.anrCheckEnabled and true or false))
        elseif choice == "14" then
            local ok, err = Config.save(conf)
            if ok then
                print("Settings saved")
                -- update logger path if changed
                local Logger = require("core.logger")
                if conf.logPath then Logger.setLogPath(conf.logPath) end
            else
                print("Failed to save: " .. tostring(err))
            end
            break
        elseif choice == "15" then
            print("Aborting without saving")
            break
        else
            print("Unknown choice")
        end
    end
end

return CLI