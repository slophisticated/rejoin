local Logger = require("core.logger")
local Shell = require("utils.shell")

local Android = {}

function Android.forceStop(packageName)
    Logger.info("Android: force stopping " .. tostring(packageName))
    Shell.exec(string.format("am force-stop %s", packageName))
end

function Android.launch(packageName)
    Logger.info("Android: launching " .. tostring(packageName))
    -- am start MAIN/LAUNCHER targeting the package explicitly first: it starts the
    -- package's own launcher task and does not depend on `cmd package resolve-activity`
    -- (often unavailable in a Termux non-adb/non-root shell). monkey is the fallback.
    local cmd = string.format("am start -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p %s", packageName)
    local ok, out = Shell.exec(cmd)
    if ok and out then
        local failed = false
        for _, h in ipairs({ "Error", "Failure", "Exception", "does not exist", "Activity not started" }) do
            if out:find(h, 1, true) then failed = true break end
        end
        if not failed then
            Logger.info("Android: am start accepted for " .. tostring(packageName))
            return true
        end
    end

    cmd = string.format("monkey -p %s -c android.intent.category.LAUNCHER 1", packageName)
    ok, out = Shell.exec(cmd)
    if ok and out and out:find("Events injected", 1, true) then
        Logger.info("Android: monkey launch injected events for " .. tostring(packageName))
        return true
    end
    if ok and out and out:find("Error", 1, true) == nil then
        Logger.info("Android: monkey launch accepted for " .. tostring(packageName))
        return true
    end

    cmd = string.format("cmd package resolve-activity --brief %s", packageName)
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

-- Open a URL. When packageName is provided, the VIEW intent is delivered to that
-- package so a scheme (e.g. robloxmobile://placeID=<id>) goes to the right clone
-- instead of Android picking a single shared default handler.
--
-- Strategies, tried in order (each logs its result so the active one is visible):
--   1) am start -a VIEW -d '<url>' -n <pkg>/com.roblox.client.ActivityProtocolLaunch
--      Forces the clone's ActivityProtocolLaunch (the deep-link->join handler) instead of
--      letting Android pick another activity (e.g. the web page) which only shows the game
--      page. This is the form that joins straight into the map on Android.
--   2) am start -a VIEW -d '<url>' -p <pkg>   (targeted package, legacy)
--   3) am start -a VIEW -d '<url>'            (untargeted fallback)
function Android.openURL(url, packageName)
    Logger.info("Android: opening URL " .. tostring(url) .. " (pkg=" .. tostring(packageName) .. ")")

    local function accepted(out)
        return out ~= nil and out:find("Error", 1, true) == nil
    end

    -- 1) Force ActivityProtocolLaunch if this is a Roblox clone.
    if packageName and packageName ~= "" then
        local proto = packageName .. "/com.roblox.client.ActivityProtocolLaunch"
        local ok1, out1 = Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s' -n %s", url, proto))
        if ok1 and accepted(out1) then
            Logger.info("Android: openURL via ActivityProtocolLaunch (" .. tostring(proto) .. ")")
            return true, out1
        end
        Logger.warn("Android: ActivityProtocolLaunch openURL failed (" .. tostring(out1) .. "), retrying -p")
    end

    -- 2) Targeted package.
    if packageName and packageName ~= "" then
        local ok, out = Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s' -p %s", url, packageName))
        if ok and accepted(out) then
            Logger.info("Android: openURL via targeted package (" .. tostring(packageName) .. ")")
            return true, out
        end
        Logger.warn("Android: targeted openURL failed for " .. tostring(packageName) .. ", retrying without target: " .. tostring(out))
    end

    -- 3) Untargeted.
    return Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s'", url))
end

return Android
