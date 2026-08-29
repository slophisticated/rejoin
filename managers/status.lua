local Logger = require("core.logger")
local APK = require("managers.apk")
local Shell = require("utils.shell")

local Status = {}

-- Per-instance runtime state.
-- instanceId -> {
--   status        = "offline"|"starting"|"ingame"|"stuck"|"freeze"|"recovery"
--   healthySince  = timestamp when the process was first seen running
--   stuckSince    = timestamp when stuck/freeze was first detected (5-min timeout base)
--   anrSeen       = last logcat sequence id that reported an ANR for this package
-- }
local states = {}

-- Defaults / config gate for freeze detection.
local freezeTimeout = 300   -- seconds
local gracePeriod = 30      -- seconds after healthy before judging ingame vs stuck
local anrEnabled = true

function Status.configure(conf)
    conf = conf or {}
    freezeTimeout = tonumber(conf.freezeTimeout) or 300
    gracePeriod = tonumber(conf.gracePeriod) or 30
    anrEnabled = conf.anrCheckEnabled ~= false -- default true
end

function Status.reset()
    states = {}
end

-- Mark an instance as currently being recovered (so the monitor shows "recovery").
function Status.beginRecovery(id)
    local s = states[id] or {}
    s.status = "recovery"
    s.stuckSince = nil
    states[id] = s
end

function Status.endRecovery(id)
    local s = states[id]
    if s and s.status == "recovery" then
        s.status = nil
    end
end

-- Read ANR lines from logcat and return a set of package names that (recently) ANR'd.
-- Best-effort: returns empty on failure/without logcat.
local function scanAnrPackages()
    local anr = {}
    if not anrEnabled then return anr end

    local ok, out = Shell.exec("logcat -d -b main -t 1000")
    if not ok or not out or out == "(dry-run)" then
        return anr
    end

    -- ActivityManager emits lines like: "ANR in com.apengjers.v3 (com.apengjers.v3/.X)"
    for line in out:gmatch("[^\r\n]+") do
        local pkg = line:match("ANR in (%S+)")
        if pkg then
            -- drop trailing '(' / component suffix if present
            pkg = pkg:gsub("%s*%(.+$", "")
            anr[pkg] = true
        end
    end
    return anr
end

-- Update the status of a single instance based on its process state and ANR logs.
-- Returns the current status string for convenience.
function Status.check(instance)
    local id = instance.id
    local pkg = instance.package
    local now = os.time()
    local s = states[id] or {}
    states[id] = s

    -- If currently being recovered, keep that status.
    if s.status == "recovery" then
        return s.status
    end

    local running = false
    if pkg then
        local ok, res = pcall(function() return APK.isRunning(pkg) end)
        running = ok and res
    end

    -- Freeze detection: ANR present for this package in recent logcat.
    local anr = scanAnrPackages()
    local frozen = anr[pkg] == true

    if not running then
        -- offline: nothing running
        s.status = "offline"
        s.healthySince = nil
        s.stuckSince = nil
        s.anrSeen = nil
        return s.status
    end

    -- Process is running.
    if not s.healthySince then
        s.healthySince = now
        s.status = "starting"
        s.stuckSince = nil
        return s.status
    end

    local healthyAge = now - s.healthySince

    if frozen then
        s.status = "freeze"
        if not s.stuckSince then s.stuckSince = now end
        return s.status
    end

    -- Not frozen and running; classify by how long it's been healthy.
    if healthyAge < gracePeriod then
        s.status = "starting"
        s.stuckSince = nil
        return s.status
    end

    -- Healthy past the grace period -> ingame.
    s.status = "ingame"
    s.stuckSince = nil
    return s.status
end

-- Whether this instance has been stuck/frozen for at least freezeTimeout seconds.
-- Returns true when it is time to relaunch.
function Status.isFreezeTimeout(id)
    local s = states[id]
    if not s then return false end
    if s.status ~= "freeze" then return false end
    if not s.stuckSince then return false end
    return (os.time() - s.stuckSince) >= freezeTimeout
end

-- Print a human-readable status table (called each monitor cycle).
function Status.printSummary(instances)
    print("\n--- Instance status ---")
    if not instances or #instances == 0 then
        print("  (no instances configured)")
        print("-----------------------")
        return
    end
    for _, inst in ipairs(instances) do
        local id = inst.id
        local s = states[id] or {}
        local status = s.status or "unknown"
        local extra = ""
        if status == "stuck" or status == "freeze" then
            if s.stuckSince then
                extra = string.format(" (since %s)", os.date("%H:%M:%S", s.stuckSince))
            end
        end
        print(string.format("  id=%s %-28s -> %s%s", tostring(id), tostring(inst.name or inst.package or "?"), status, extra))
    end
    print("-----------------------")
end

return Status
