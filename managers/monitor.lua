local Logger = require("core.logger")
local Timer = require("utils.timer")
local Status = require("managers.status")

local Monitor = {}
local running = false
local interval = 5
local instanceManager = nil
local recoveryManager = nil
local apkManager = nil

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
    Status.reset()
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

            -- Legacy health check / recovery for offline instances (process not running).
            local healthy = (status == "ingame" or status == "starting" or status == "freeze")
            if not healthy and pkg then
                local ok, res = pcall(function() return apkManager.isRunning(pkg) end)
                healthy = ok and res
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

        Timer.sleep(interval)
    end

    return true
end

function Monitor.stop()
    running = false
    Logger.info("Monitor: stopped")
end

return Monitor
