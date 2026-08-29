local Logger = require("core.logger")
local Shell = require("utils.shell")

local Android = {}

function Android.forceStop(packageName)
    Logger.info("Android: force stopping " .. tostring(packageName))
    Shell.exec(string.format("am force-stop %s", packageName))
end

function Android.launch(packageName)
    Logger.info("Android: launching " .. tostring(packageName))
    -- monkey first: does not depend on `cmd package resolve-activity`, which may be
    -- unavailable in a Termux (non-adb, non-root) shell. Resolve is only a fallback.
    local ok, out = Shell.exec(string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", packageName))
    if ok and out and out:find("Events injected", 1, true) then
        Logger.info("Android: monkey launch injected events for " .. tostring(packageName))
        return true
    end
    if ok and out and out:find("Error", 1, true) == nil then
        Logger.info("Android: monkey launch accepted for " .. tostring(packageName))
        return true
    end

    local cmd = string.format("cmd package resolve-activity --brief %s", packageName)
    local rok, rout = Shell.exec(cmd)
    local component = nil
    if rok and rout then
        for line in rout:gmatch("[^\r\n]+") do
            local comp = line:match("(%S+%/%S+)")
            if comp then component = comp break end
        end
    end
    if component then
        Logger.info("Android: fallback resolved component: " .. tostring(component))
        Shell.exec(string.format("am start -n %s", component))
    end
    return false
end

function Android.openURL(url)
    Logger.info("Android: opening URL " .. tostring(url))
    Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s'", url))
end

return Android
