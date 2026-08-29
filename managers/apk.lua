local Logger = require("core.logger")
local Shell = require("utils.shell")

local APKManager = {}

-- Resolve the default launchable activity component for a package (best-effort).
-- Returns the component string like "com.roblox.client/.Activity" or nil on failure.
function APKManager.resolveLaunchComponent(packageName)
    -- cmd package resolve-activity --brief returns the package/activity component on the last line
    local cmd = string.format("cmd package resolve-activity --brief %s", packageName)
    local ok, out = Shell.exec(cmd)
    if ok and out then
        for line in out:gmatch("[^\r\n]+") do
            local comp = line:match("(%S+%/%S+)")
            if comp then
                return comp
            end
        end
    end
    return nil
end

-- Launch an APK by package name. This is a best-effort resolver for Termux/Android.
-- Tries the launchable activity via `cmd package resolve-activity`, falling back to
-- `monkey` (which does not need a hardcoded component) if resolution fails.
function APKManager.launch(packageName)
    Logger.info("APKManager: launching package: " .. tostring(packageName))

    -- 1) Resolve the real launchable activity component (fixes hardcoded .MainActivity)
    local component = APKManager.resolveLaunchComponent(packageName)
    if component then
        Logger.info("APKManager: resolved launch component: " .. tostring(component))
        local ok, out = Shell.exec(string.format("am start -W -n %s", component))
        if ok and out and out:find("Error", 1, true) == nil then
            return true, out
        end
        Logger.warn("APKManager: am start failed, falling back to monkey: " .. tostring(out))
    else
        Logger.warn("APKManager: could not resolve launch component for " .. tostring(packageName))
    end

    -- 2) Fallback: monkey launches the main activity of a package by name without a component
    local cmd = string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", packageName)
    local ok2, out2 = Shell.exec(cmd)
    if ok2 and out2 then
        -- monkey exits 0 even on some errors; warn but don't block recovery
        if out2:find("Events injected", 1, true) then
            Logger.info("APKManager: monkey launch injected events for " .. tostring(packageName))
            return true, out2
        end
        Logger.warn("APKManager: monkey reported no injected events for " .. tostring(packageName))
    end
    return ok2 or false, out2
end

function APKManager.forceStop(packageName)
    Logger.info("APKManager: force stopping: " .. tostring(packageName))
    local cmd = string.format("am force-stop %s", packageName)
    local ok, out = Shell.exec(cmd)
    return ok, out
end

-- Check whether a package has a running process. Tries pidof, then pgrep, then ps.
-- Returns true if any method finds a matching process, false otherwise.
function APKManager.isRunning(packageName)
    if not packageName or packageName == "" then return false end
    local pkg = packageName:gsub("['\" ]", "")

    -- 1) pidof (busybox sometimes missing)
    local ok, out = Shell.exec(string.format("pidof %s", pkg))
    if ok and out and out ~= "" and out ~= "(dry-run)" then
        return true
    end

    -- 2) pgrep
    ok, out = Shell.exec(string.format("pgrep -f %s", pkg))
    if ok and out and out ~= "" and out ~= "(dry-run)" then
        return true
    end

    -- 3) ps fallback (match process lines that contain the package name)
    ok, out = Shell.exec("ps -A")
    if ok and out and out ~= "(dry-run)" then
        for line in (out or ""):gmatch("[^\r\n]+") do
            if line:find(pkg, 1, true) then
                return true
            end
        end
    end

    return false
end

return APKManager
