local Logger = require("core.logger")
local Shell = require("utils.shell")
local Config = require("core.config")

-- Reduces RAM/CPU contention between the Roblox clones by deprioritizing them.
--
-- With four floating-window clones running at once they compete for CPU time, I/O and
-- memory. Android runs each clone as its own process, so as root we can tune their
-- Linux process priorities directly:
--   * nice   -> CPU scheduling priority (higher = lower priority, 19 = lowest)
--   * ionice -> I/O class (class 3 = idle, only runs when nobody else needs the disk)
-- Every clone is deprioritized equally (chosen over keeping the focused one boosted).
--
-- IMPORTANT: the clone process is relaunched (force-stop + start) on every recovery, so
-- it gets a NEW pid every time. renice/ionice act on a pid, so Optimizer must be re-applied
-- after every launch / recovery that restarts a clone.

local Optimizer = {}

local function safeConfig()
    local ok, conf = pcall(function() return Config.get() end)
    if not ok or type(conf) ~= "table" then return {} end
    return conf or {}
end

-- Current optimizer config: { enabled, renice, ionice }.
function Optimizer.getConfig()
    local opt = safeConfig().optimizer
    if type(opt) ~= "table" then opt = {} end
    return {
        enabled = opt.enabled ~= false,
        renice = tonumber(opt.renice) or 19,
        ionice = tonumber(opt.ionice) or 3,
    }
end

-- Resolve the main process pid(s) for a package via pidof. Returns "" (false-y) when
-- the process isn't running, so callers can skip a not-yet-up clone without error.
local function getPids(pkg)
    if not pkg or pkg == "" then return "" end
    local ok, out = pcall(function() return Shell.exec("pidof " .. pkg) end)
    if not ok or not out then return "" end
    return (out:gsub("\n", " ")):gsub("%s+$", "")
end

-- Lower one specific pid's CPU + I/O priority. Best-effort: never throws.
local function applyToPid(pid, cfg)
    if not pid or pid == "" then return end
    local reniceCmd = string.format("renice %d -p %s", cfg.renice, pid)
    local okR, outR = pcall(function() return Shell.exec(reniceCmd) end)
    if not okR then
        Logger.debug("Optimizer: renice failed for pid " .. pid)
    elseif outR and outR ~= "(dry-run)" then
        Logger.debug("Optimizer: " .. tostring(outR))
    end

    -- ionice: class 3 (idle). Best-effort; some kernels/toolboxes lack ionice.
    local okI = pcall(function() return Shell.exec(string.format("ionice -c %d -p %s", cfg.ionice, pid)) end)
    if not okI then
        Logger.debug("Optimizer: ionice unavailable/unsupported, skipping I/O tuning")
    end
end

-- Apply deprioritization to a single instance (by package). No-op if disabled or when
-- the package isn't running yet. Returns true if something was applied.
function Optimizer.applyForInstance(instance)
    local cfg = Optimizer.getConfig()
    if not cfg.enabled then return false end
    local pkg = instance and instance.package
    if not pkg or pkg == "" then return false end

    local pids = getPids(pkg)
    if not pids or pids == "" then return false end
    for pid in pids:gmatch("%S+") do
        pcall(function() applyToPid(pid, cfg) end)
    end
    Logger.debug(string.format("Optimizer: deprioritized %s (nice=%d ionice=%d)", pkg, cfg.renice, cfg.ionice))
    return true
end

-- Apply deprioritization to all configured instances.
function Optimizer.applyAll()
    local ok, conf = pcall(function() return Config.get() end)
    if not ok or not conf or type(conf.instances) ~= "table" then return 0 end
    if not Optimizer.getConfig().enabled then return 0 end

    local applied = 0
    for _, inst in ipairs(conf.instances) do
        if Optimizer.applyForInstance(inst) then applied = applied + 1 end
    end
    return applied
end

return Optimizer
