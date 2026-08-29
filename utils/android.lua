local Logger = require("core.logger")
local Shell = require("utils.shell")

local Android = {}

function Android.forceStop(packageName)
    Logger.info("Android: force stopping " .. tostring(packageName))
    Shell.exec(string.format("am force-stop %s", packageName))
end

function Android.launch(packageName)
    Logger.info("Android: launching " .. tostring(packageName))
    -- Prefer resolving the real launchable activity; fall back to monkey which needs no component
    local cmd = string.format("cmd package resolve-activity --brief %s", packageName)
    local ok, out = Shell.exec(cmd)
    local component = nil
    if ok and out then
        for line in out:gmatch("[^\r\n]+") do
            local comp = line:match("(%S+%/%S+)")
            if comp then component = comp break end
        end
    end
    if component then
        Shell.exec(string.format("am start -W -n %s", component))
    else
        Shell.exec(string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", packageName))
    end
end

function Android.openURL(url)
    Logger.info("Android: opening URL " .. tostring(url))
    Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s'", url))
end

return Android
