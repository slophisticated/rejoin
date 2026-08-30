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

-- ANSI colors
local C = {
    green  = "\27[32m",
    red    = "\27[31m",
    yellow = "\27[33m",
    cyan   = "\27[36m",
    dim    = "\27[2m",
    reset  = "\27[0m",
}

-- Human label + color for a status (used by the monitor table).
local STATUS_UI = {
    ingame   = { "Running",  C.green },
    stuck    = { "Stuck",    C.red },
    freeze   = { "Stuck",    C.red },
    recovery = { "Recovery", C.yellow },
    starting = { "Starting", C.cyan },
    offline  = { "Offline",  C.dim },
}

-- Best-effort memory + storage readout, cached to avoid shell cost every cycle.
local sysCache = { memAt = 0, memLine = nil, diskAt = 0, diskLine = nil }
local SYS_CACHE_TTL = 30

-- Read MemTotal/MemAvailable from /proc/meminfo (kB) via shell.
-- Returns a content line like "58% (860MB Free)" or nil on failure.
local function memoryLine()
    local now = os.time()
    if sysCache.memAt == 0 or (now - sysCache.memAt) >= SYS_CACHE_TTL then
        sysCache.memAt = now
        sysCache.memLine = nil
        local ok, out = Shell.exec("cat /proc/meminfo")
        if ok and out and out ~= "(dry-run)" then
            local total, avail
            for line in out:gmatch("[^\r\n]+") do
                if not total then
                    total = tonumber(line:match("MemTotal:%s*(%d+)"))
                end
                if not avail then
                    avail = tonumber(line:match("MemAvailable:%s*(%d+)"))
                end
            end
            if total and total > 0 then
                local used = avail and (total - avail) or 0
                local pct = math.floor(used / total * 100 + 0.5)
                local freeMb = avail and math.floor(avail / 1024) or 0
                sysCache.memLine = string.format("%d%% (%dMB Free)", pct, freeMb)
            end
        end
    end
    return sysCache.memLine
end

-- Read free space from `df` (best-effort). Picks the storage mount if present
-- (/sdcard, /emulated, or the root mount), else the first real block. Returns a
-- line like "300GB Free" or nil on failure.
local function storageLine()
    local now = os.time()
    if sysCache.diskAt == 0 or (now - sysCache.diskAt) >= SYS_CACHE_TTL then
        sysCache.diskAt = now
        sysCache.diskLine = nil
        local ok, out = Shell.exec("df -h 2>/dev/null")
        if ok and out and out ~= "(dry-run)" then
            local fallbackAvail
            for line in out:gmatch("[^\r\n]+") do
                -- df -h columns: Filesystem Size Used Avail Use% Mounted on
                local avail, mnt = line:match("%S+%s+%S+%s+%S+%s+(%S+)%s+%S+%%%s+(.+)")
                if avail then
                    local isWanted = mnt and (
                        mnt:find("/sdcard", 1, true) or
                        mnt:find("/emulated", 1, true) or
                        mnt == "/"
                    )
                    if isWanted then
                        sysCache.diskLine = avail .. " Free"
                        break
                    end
                    if not fallbackAvail then fallbackAvail = avail end
                end
            end
            if not sysCache.diskLine and fallbackAvail then
                sysCache.diskLine = fallbackAvail .. " Free"
            end
        end
    end
    return sysCache.diskLine
end

-- Print a full-screen, colorized status table (clears the terminal each cycle).
function Status.printSummary(instances)
    local LCOL = 24   -- width of the left (Instance) column
    local RCOL = 18   -- width of the right (Status/Value) column

    -- Build one body row. `rightText` is plain so padding is based on visible chars;
    -- the color is applied around the visible text only, so all rows align equally.
    local function bodyRow(left, rightText, rightColor)
        if #left > LCOL then left = left:sub(1, LCOL) end
        if #rightText > RCOL then rightText = rightText:sub(1, RCOL) end
        local r = rightText
        if rightColor then
            r = rightColor .. rightText .. C.reset
        end
        return "| " .. left .. string.rep(" ", LCOL - #left)
            .. " | " .. r .. string.rep(" ", RCOL - #rightText) .. " |"
    end

    -- One row is LCOL + RCOL + 7 chars; build the border from the same width so the
    -- vertical separators line up exactly (previously border was 4 short -> misaligned).
    local bodyWidth = LCOL + RCOL + 7
    local border = "+" .. string.rep("-", bodyWidth - 2) .. "+"

    -- Assemble the whole frame into a single string so we can clear + write at once,
    -- avoiding the cursor-home artifact that scattered borders across the middle of rows.
    local sb = {}
    table.insert(sb, border)
    table.insert(sb, bodyRow("Instance", "Status"))
    table.insert(sb, border)

    if not instances or #instances == 0 then
        table.insert(sb, bodyRow("(no instances)", "--", C.dim))
        table.insert(sb, border)
    else
        for _, inst in ipairs(instances) do
            local id = inst.id or inst.name or "?"
            local pkg = inst.package or inst.name or tostring(id)
            local s = states[id]
            local status = s and s.status or "offline"
            local ui = STATUS_UI[status] or { status, C.dim }
            table.insert(sb, bodyRow(pkg, ui[1] or "Unknown", ui[2]))
        end
        table.insert(sb, border)
    end

    table.insert(sb, bodyRow("Memory Usage", memoryLine() or "--"))
    table.insert(sb, bodyRow("Storage Available", storageLine() or "--"))
    table.insert(sb, border)

    -- Clear + write the frame in one shot, then a dim footer line.
    io.write("\27[2J\27[H" .. table.concat(sb, "\n") .. "\n")
    io.write(C.dim .. "(tekan Ctrl+C untuk berhenti)" .. C.reset .. "\n")
    io.flush()
end

return Status
