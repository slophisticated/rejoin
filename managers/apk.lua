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

-- Launch an APK by package name for Termux/Android.
--
-- Order of attempts:
--   1) `am start -a MAIN -c LAUNCHER -p <pkg>`  -- targets the package explicitly and
--      starts its own task/launcher activity. Works for cloned apps (each clone is a
--      distinct package) and does NOT depend on `cmd package resolve-activity`, which is
--      often unavailable in a Termux (non-adb, non-root) shell.
--   2) `monkey -p <pkg> -c LAUNCHER 1`          -- legacy fallback.
--   3) resolve-activity + `am start -n <component>` -- best-effort fallback.
--
-- Returns (success, output_or_err).
function APKManager.launch(packageName)
    Logger.info("APKManager: launching package: " .. tostring(packageName))

    -- 1) Primary: am start MAIN/LAUNCHER targeting the package explicitly.
    local cmd = string.format("am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p %s", packageName)
    Logger.info("APKManager: exec: " .. cmd)
    local ok, out = Shell.exec(cmd)
    local failedHint = { "Error", "Failure", "Exception", "does not exist", "is not allowed", "Activity not started" }
    local failed = false
    if ok and out then
        for _, h in ipairs(failedHint) do
            if out:find(h, 1, true) then failed = true break end
        end
        if not failed then
            Logger.info("APKManager: am start accepted for " .. tostring(packageName))
            return true, out
        end
    else
        failed = true
    end
    Logger.warn("APKManager: am start launch failed/not accepted for " .. tostring(packageName) .. ": " .. tostring(out))

    -- 2) Fallback: monkey launches the main activity of a package by name (no component needed)
    cmd = string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", packageName)
    Logger.info("APKManager: fallback exec: " .. cmd)
    ok, out = Shell.exec(cmd)
    if ok and out then
        -- monkey exits 0 even on some errors; only treat as success on injected events
        if out:find("Events injected", 1, true) then
            Logger.info("APKManager: monkey launch injected events for " .. tostring(packageName))
            return true, out
        end
        if out:find("Error", 1, true) == nil then
            Logger.info("APKManager: monkey launch accepted for " .. tostring(packageName))
            return true, out
        end
        Logger.warn("APKManager: monkey reported an error for " .. tostring(packageName) .. ": " .. tostring(out))
    else
        Logger.warn("APKManager: monkey launch failed/empty for " .. tostring(packageName))
    end

    -- 3) Fallback: resolve the launchable activity then `am start` (best-effort)
    local component = APKManager.resolveLaunchComponent(packageName)
    if component then
        Logger.info("APKManager: fallback resolved launch component: " .. tostring(component))
        local ok2, out2 = Shell.exec(string.format("am start -n %s", component))
        if ok2 and out2 and out2:find("Error", 1, true) == nil then
            return true, out2
        end
        Logger.warn("APKManager: fallback am start failed for " .. tostring(packageName) .. ": " .. tostring(out2))
    end

    return false, out
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
