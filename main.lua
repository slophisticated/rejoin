local Logger = require("core.logger")
local State = require("core.state")

Logger.info(State.get())

State.set("MENU")

Logger.info(State.get())

-- Parse simple CLI flags
local args = arg or {}
local headless = false
local skipWizard = false
local startMonitorFlag = false
local configSource = nil
local dryRun = false
for i = 1, #args do
    local a = args[i]
    if a == "--headless" or a == "--no-interactive" then headless = true end
    if a == "--no-wizard" then skipWizard = true end
    if a == "--start-monitor" then startMonitorFlag = true end
    if a == "--dry-run" then dryRun = true end
    if a == "--config" then
        local nextArg = args[i+1]
        if nextArg and nextArg:sub(1,2) ~= "--" then
            configSource = nextArg
        end
    end
end

-- Set runtime dry-run early
local Runtime = require("core.runtime")
if dryRun then
    Runtime.setDryRun(true)
    Logger.info("Runtime: dry-run mode enabled")
end

-- Ensure configuration exists (setup will copy template -> config if needed)
local Setup = require("core.setup")
local ok, created_or_err = Setup.ensureConfig(configSource)
if not ok then
    Logger.error("Failed to ensure config: " .. tostring(created_or_err))
else
    if created_or_err == true and not skipWizard and not headless then
        -- config was just created from template; run the interactive setup wizard
        local Wizard = require("core.setup_wizard")
        local wok, werr = Wizard.run()
        if not wok then
            Logger.warn("Setup wizard did not complete: " .. tostring(werr))
            Logger.info("You can edit config/config.lua manually or re-run the wizard later.")
        end
    end
end

local Config = require("core.config")

-- Initialize logger path from loaded config
local conf = Config.get() or {}
if conf.logPath then
    Logger.setLogPath(conf.logPath)
end

local data = conf

print("monitorInterval=", data.monitorInterval)

local InstanceManager = require("managers.instance")
InstanceManager.load(Config.get())

print("instance count=", InstanceManager.count())

-- Headless mode: optionally start monitor immediately
if headless and startMonitorFlag then
    Logger.info("Headless mode: starting monitor")
    local Monitor = require("managers.monitor")
    Monitor.start(Config.get())
    os.exit(0)
end

-- Interactive menu loop
local function prompt(msg)
    io.write(msg)
    io.flush()
    local line = io.read()
    -- Ctrl+C / EOF while in the menu returns nil; treat it as a clean hard stop.
    if line == nil then
        print("\nInterrupted by Ctrl+C; exiting.")
        os.exit(0)
    end
    return line
end

while true do
    print('\nMain Menu:\n  1) Launch All + Monitor\n  2) Instances Manager\n  3) Settings\n  4) View Logs\n  5) Start Monitor\n  6) Exit\n  (tekan Ctrl+C untuk berhenti)\n')
    local choice = prompt("Choose: ") or ""
    choice = choice:match("^%s*(.-)%s*$")
    if choice == "1" then
        local Recovery = require("managers.recovery")
        local list = InstanceManager.getAll()
        if #list == 0 then
            print("No instances configured.")
        else
            print("Launching all instances (one at a time)...")
            print("(tekan Ctrl+C untuk berhenti monitor)")
            local APK = require("managers.apk")
            local packages = {}
            for _, inst in ipairs(list) do
                if inst.package then table.insert(packages, inst.package) end
            end
            local baseline = APK.countRunning(packages)
            print(string.format("(already running %d instance(s))", baseline))
            for i, inst in ipairs(list) do
                print(string.format("  launching id=%s name=%s package=%s", tostring(inst.id), tostring(inst.name or ""), tostring(inst.package or "")))
                local ok = Recovery.launchAndJoin(inst)
                if not ok then
                    print(string.format("  launch failed for id=%s", tostring(inst.id)))
                else
                    print("  waiting for it to open before the next one...")
                    Recovery.waitUntilRunning(inst, { targetCount = baseline + i, instances = list })
                end
            end
            print("Starting monitor...")
            local Monitor = require("managers.monitor")
            Monitor.start(Config.get())
            break
        end
    elseif choice == "2" then
        local InstancesCLI = require("core.instances_cli")
        InstancesCLI.run()
    elseif choice == "3" then
        local SettingsCLI = require("core.settings_cli")
        SettingsCLI.run()
    elseif choice == "4" then
        local LogsCLI = require("core.logs_cli")
        LogsCLI.run()
    elseif choice == "5" then
        local Monitor = require("managers.monitor")
        print("(tekan Ctrl+C untuk berhenti monitor)")
        Monitor.start(Config.get())
    elseif choice == "6" then
        print("Exiting main")
        break
    else
        print("Unknown choice")
    end
end
