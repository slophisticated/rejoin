local Logger = require("core.logger")
local Timer = require("utils.timer")
local Status = require("managers.status")

local Monitor = {}
local running = false
local interrupted = false
local interval = 5
local instanceManager = nil
local recoveryManager = nil
local apkManager = nil

-- Install a SIGINT handler via lua-posix so Ctrl+C actually stops monitoring on
-- Termux. Without a handler, `os.execute("sleep")` inside Timer.sleep swallows the
-- signal (POSIX system() blocks SIGINT), so Ctrl+C does nothing while monitoring.
-- The handler just flips flags; the sleep loop checks them each 0.25s and exits.
local function installSignalHandler()
    local ok, posix = pcall(require, "posix.signal")
    if not ok or not posix then
        Logger.warn("Monitor: lua-posix not found; Ctrl+C won't stop the monitor. Install with: pkg install lua-posix")
        return false
    end
    local sigint = posix.SIGINT or 2
    pcall(function()
        posix.signal(sigint, function()
            running = false
            interrupted = true
        end)
    end)
    Logger.info("Monitor: SIGINT handler installed (Ctrl+C will stop monitoring)")
    return true
end

-- track instances currently undergoing recovery to avoid duplicate recoveries
local recovering = {}

local function isRecovering(id)
    return recovering[id] == true
end

local function setRecovering(id, val)
    if id == nil then return end
    if val then recovering[id] = true else recovering[id] = nil end
end

function Monitor.start(conf)
    interval = conf and conf.monitorInterval or interval
    instanceManager = require("managers.instance")
    recoveryManager = require("managers.recovery")
    apkManager = require("managers.apk")
    Status.configure(conf)

    if running then
        Logger.warn("Monitor already running")
        return false
    end

    running = true
    interrupted = false
    Status.reset()
    Status.resetDashboard()
    installSignalHandler()
    -- Full-screen dashboard: hide console log lines while monitoring so they don't push
    -- the dashboard around (log lines still go to the log file).
    Logger.setConsoleVisible(false)
    -- Clear the screen so leftover menu/launch text doesn't sit above the dashboard.
    io.write("\27[2J\27[H")
    Logger.info("Monitor: starting (interval=" .. tostring(interval) .. ")")

    while running do
        local instances = instanceManager.getAll()
        for i, inst in ipairs(instances) do
            local id = inst.id or i
            local name = tostring(inst.name or id)
            local pkg = inst.package
            Logger.debug(string.format("Monitor: checking instance %s (%s)", name, tostring(pkg)))

            -- Update per-instance status (running / starting / ingame / stuck / freeze / recovery)
            local status
            local okStatus, resStatus = pcall(function() return Status.check(inst) end)
            status = okStatus and resStatus or "unknown"

            -- If frozen/stuck long enough, relaunch the app.
            local timeToRelaunch = false
            if status == "freeze" then
                local p_ok, should = pcall(function() return Status.isFreezeTimeout(id) end)
                timeToRelaunch = p_ok and should
            end
            if timeToRelaunch then
                Logger.warn(string.format("Monitor: instance %s frozen too long; relaunching", name))
                Status.beginRecovery(id)
                local r_ok, r_err = pcall(function()
                    return recoveryManager.relaunch(inst)
                end)
                if not r_ok or not r_err then
                    Logger.error(string.format("Monitor: relaunch failed for %s: %s", name, tostring(r_err)))
                else
                    Logger.info(string.format("Monitor: relaunched %s", name))
                end
                Status.endRecovery(id)
            end

            -- Health is based on the REAL process state every cycle (not the status
            -- memory), so a clone whose UI was closed is detected and recovered. Previously
            -- a stale "ingame" status memory kept the instance forever "healthy" and the
            -- recovery was never triggered (the app stayed closed).
            local healthy = false
            if pkg then
                -- For floating-window clones a force-close leaves a stub process alive, so
                -- process existence can never signal "UI closed". Decide health from window
                -- visibility first (hasVisibleWindow), falling back to the process state only
                -- when dumpsys is unavailable.
                local ok, vis = pcall(function() return apkManager.hasVisibleWindow(pkg) end)
                if ok and vis ~= nil then
                    healthy = vis
                else
                    local ok2, run = pcall(function() return apkManager.isRunning(pkg) end)
                    healthy = ok2 and run
                end
            end

            if healthy then
                Logger.debug(string.format("Monitor: instance healthy: %s", name))
            else
                Logger.warn(string.format("Monitor: instance not healthy: %s", name))
                if isRecovering(id) then
                    Logger.info(string.format("Monitor: recovery already in progress for %s; skipping", name))
                else
                    -- mark as recovering and run recovery (synchronous). This avoids overlapping recoveries.
                    setRecovering(id, true)
                    Status.beginRecovery(id)
                    local p_ok, recovered = pcall(function()
                        return recoveryManager.checkAndRecover(inst)
                    end)
                    if not p_ok then
                        Logger.error(string.format("Monitor: recovery raised an error for %s: %s", name, tostring(recovered)))
                    elseif recovered then
                        Logger.info(string.format("Monitor: recovery succeeded for %s", name))
                    else
                        Logger.error(string.format("Monitor: recovery failed for %s (all attempts)", name))
                    end
                    Status.endRecovery(id)
                    setRecovering(id, false)
                end
            end

            if not running then break end
        end

        -- Print the per-instance status table for the user to see.
        Status.printSummary(instances)

        Timer.sleepInterruptible(interval, function() return not running end)
    end

    -- Monitor stopped: restore console output and cursor, then leave a clean line.
    Logger.setConsoleVisible(true)
    io.write("\27[?25h\r\n")
    io.flush()
    return true
end

function Monitor.stop()
    running = false
    Logger.info("Monitor: stopped")
end

function Monitor.interrupted()
    return interrupted
end

return Monitor
