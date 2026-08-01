local Logger = require("core.logger")
local Shell = require("utils.shell")

local APKManager = {}

-- Launch an APK by package name. This is a best-effort stub for Termux/Android.
function APKManager.launch(packageName)
    Logger.info("APKManager: launching package: " .. tostring(packageName))
    -- Using am start; activity/component may need adjustment per package
    local cmd = string.format("am start -n %s/.MainActivity", packageName)
    local ok, out = Shell.exec(cmd)
    return ok, out
end

function APKManager.forceStop(packageName)
    Logger.info("APKManager: force stopping: " .. tostring(packageName))
    local cmd = string.format("am force-stop %s", packageName)
    local ok, out = Shell.exec(cmd)
    return ok, out
end

function APKManager.isRunning(packageName)
    -- Simple check using pidof (may not be available on all systems)
    local cmd = string.format("pidof %s", packageName)
    local ok, out = Shell.exec(cmd)
    return ok and out ~= ""
end

return APKManager
