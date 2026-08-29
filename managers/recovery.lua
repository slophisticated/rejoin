local Logger = require("core.logger")
local APK = require("managers.apk")
local AutoExecute = require("managers.autoexecute")
local UtilsAndroid = require("utils.android")
local RobloxLink = require("utils.roblox_link")
local Timer = require("utils.timer")
local Config = require("core.config")

local Recovery = {}

local function safeNumber(v, default)
    v = tonumber(v)
    if v and v > 0 then return v end
    return default
end

local function isHealthy(instance)
    local pkg = instance and instance.package
    if not pkg then return false end
    -- Check process running
    local running = APK.isRunning(pkg)
    if running then return true end
    return false
end

-- Open the instance game/private-server link, normalizing it to a safe form first.
-- Best-effort: logs and does not fail the caller on a bad/missing link.
local function openGameLink(instance)
    local pkg = instance and instance.package
    if not instance.privateServer then
        return true
    end
    local okLink, link = RobloxLink.normalize(instance.privateServer)
    if okLink then
        Logger.info("Recovery: opening game link for " .. tostring(instance.name or pkg) .. ": " .. tostring(link))
        UtilsAndroid.openURL(link, pkg)
        return true
    end
    Logger.warn("Recovery: skipping invalid game link for " .. tostring(instance.name or pkg) .. ": " .. tostring(link))
    return false
end

-- Launch an instance's app and join its game (best-effort), no retry loop.
-- Returns true if the app launch succeeded.
function Recovery.launchAndJoin(instance)
    local pkg = instance and instance.package
    if not pkg then
        Logger.error("Recovery.launchAndJoin: instance has no package")
        return false
    end

    local conf = Config.get() or {}
    Logger.info("Recovery.launchAndJoin: launching " .. tostring(instance.name or pkg))

    local ok, err = APK.launch(pkg)
    if not ok then
        Logger.error("Recovery.launchAndJoin: launch failed for " .. tostring(instance.name or pkg) .. ": " .. tostring(err))
        return false
    end

    -- Join game from link (best-effort)
    openGameLink(instance)

    Logger.info("Recovery.launchAndJoin: done for " .. tostring(instance.name or pkg))
    return true
end

-- Wait until an instance's app process is observed running (isRunning true), with a
-- short settle delay after it is detected. Used by "Launch All" to launch clones one at
-- a time so each floating-window clone has a chance to come up before the next is started.
-- Options (all optional): interval, timeout, settleDelay.
-- Returns true if the process was detected, false on timeout.
function Recovery.waitUntilRunning(instance, opts)
    local pkg = instance and instance.package
    if not pkg then return false end

    local conf = Config.get() or {}
    opts = opts or {}
    local interval = safeNumber(opts.interval, safeNumber(conf.launchWaitInterval, 3))
    local timeout = safeNumber(opts.timeout, safeNumber(conf.launchWaitTimeout, 90))
    local settle = safeNumber(opts.settleDelay, safeNumber(conf.launchSettleDelay, 5))

    local name = tostring(instance.name or pkg)
    Logger.info("Recovery.waitUntilRunning: waiting for " .. name .. " to open (timeout=" .. tostring(timeout) .. "s)")

    local started = os.time()
    while true do
        if APK.isRunning(pkg) then
            local elapsed = os.time() - started
            Logger.info(string.format("Recovery.waitUntilRunning: %s opened after %ds; settling %ds", name, elapsed, settle))
            Timer.sleep(settle)
            return true
        end
        if (os.time() - started) >= timeout then
            Logger.warn(string.format("Recovery.waitUntilRunning: %s not detected within %ds; continuing", name, timeout))
            return false
        end
        Timer.sleep(interval)
    end
end

-- Force-stop and relaunch an instance's app (used when an app has been frozen/stuck
-- for too long). Best-effort, no full recovery retry loop.
function Recovery.relaunch(instance)
    local pkg = instance and instance.package
    if not pkg then
        Logger.error("Recovery.relaunch: instance has no package")
        return false
    end

    Logger.info("Recovery.relaunch: force-stopping and relaunching " .. tostring(instance.name or pkg))

    local ok_fs = APK.forceStop(pkg)
    if not ok_fs then
        Logger.debug("Recovery.relaunch: forceStop returned false for " .. tostring(pkg))
    end

    Timer.sleep(1)

    local ok, err = APK.launch(pkg)
    if not ok then
        Logger.error("Recovery.relaunch: launch failed for " .. tostring(instance.name or pkg) .. ": " .. tostring(err))
        return false
    end

    Logger.info("Recovery.relaunch: relaunched " .. tostring(instance.name or pkg))
    return true
end

-- Perform recovery for a single instance table (expects fields: package, privateServer)
-- Includes retries and simple health checks
function Recovery.checkAndRecover(instance)
    local pkg = instance and instance.package
    if not pkg then
        Logger.error("Recovery: instance has no package")
        return false
    end

    local conf = Config.get() or {}
    local retries = safeNumber(conf.recoveryRetries, 3)
    local delay = safeNumber(conf.recoveryDelay, 3)
    local checkTimeout = safeNumber(conf.checkTimeout, 15)

    Logger.info("Recovery: starting for " .. tostring(instance.name or pkg))

    for attempt = 1, retries do
        Logger.info(string.format("Recovery: attempt %d/%d for %s", attempt, retries, tostring(instance.name or pkg)))

        -- Force stop first
        local ok_fs = APK.forceStop(pkg)
        if not ok_fs then
            Logger.debug("Recovery: forceStop returned false/err for " .. tostring(pkg))
        end

        -- small pause to let system settle
        Timer.sleep(1)

        -- Launch app
        local ok_launch, launchOut = APK.launch(pkg)
        if not ok_launch then
            Logger.warn(string.format("Recovery: launch failed for %s (attempt %d): %s", tostring(pkg), attempt, tostring(launchOut)))
            -- retry after delay
            if attempt < retries then
                Logger.info("Recovery: retrying after delay " .. tostring(delay))
                Timer.sleep(delay)
                goto continue_retry
            end
            break
        end

        -- Wait/poll for process to be running up to checkTimeout
        local waited = 0
        local healthy = false
        while waited < checkTimeout do
            if isHealthy(instance) then
                healthy = true
                break
            end
            Timer.sleep(1)
            waited = waited + 1
        end

        if healthy then
            Logger.info("Recovery: instance appears healthy: " .. tostring(instance.name or pkg))

            -- Inject AutoExecute (best-effort)
            local ok2, err = AutoExecute.inject(instance)
            if not ok2 then
                Logger.warn("Recovery: autoexecute inject failed: " .. tostring(err))
            end

            -- Open game / private server URL if present (normalize to a safe form first)
            openGameLink(instance)

            Logger.info("Recovery: completed successfully for " .. tostring(instance.name or pkg))
            return true
        else
            Logger.warn(string.format("Recovery: instance did not become healthy after %d seconds (attempt %d)", checkTimeout, attempt))
            if attempt < retries then
                Logger.info("Recovery: retrying after delay " .. tostring(delay))
                Timer.sleep(delay)
            end
        end

        ::continue_retry::
    end

    Logger.error("Recovery: all attempts failed for " .. tostring(instance.name or pkg))
    return false
end

return Recovery
