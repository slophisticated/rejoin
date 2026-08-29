local Logger = require("core.logger")
local Runtime = require("core.runtime")

local Shell = {}

-- Whether commands should run with root (`su -c '...'`). Reads `useRoot` from the
-- project config; defaults to true because the supported setup is a rooted device
-- (Magisk). On a non-root device set `useRoot = false` in config/config.lua.
local function rootEnabled()
    local ok, conf = pcall(function() return require("core.config").get() end)
    if ok and conf and conf.useRoot ~= nil then
        return conf.useRoot == true
    end
    return true
end

-- Wrap a shell command in `su -c '...'` so ps/pidof/pgrep/am/logcat run as root. A
-- rooted device running Termux as a NORMAL user cannot see other apps' processes
-- (Android 11+), which previously made every process probe return empty and broke
-- per-instance health/Launch All detection. Running as root fixes that.
local function runWithRoot(cmd)
    if not rootEnabled() then
        return cmd
    end
    local inner = cmd:gsub("'", "'\\''")
    return "su -c '" .. inner .. "'"
end

-- Execute a command and return (ok, output). Uses io.popen to capture stdout.
-- If runtime dry-run is enabled, log the command and return a simulated success output.
function Shell.exec(cmd)
    if not cmd then return false, "no_cmd" end
    if Runtime.isDryRun() then
        Logger.debug("[dry-run] Shell.exec: " .. cmd)
        -- Simulate outputs for common probes
        if cmd:match("^pidof %S+") then
            -- simulate process not running by default (empty output)
            return true, ""
        end
        return true, "(dry-run)"
    end

    local full = runWithRoot(cmd)
    Logger.debug("Shell.exec: " .. full)
    local f = io.popen(full .. " 2>&1")
    if not f then return false, "popen_failed" end
    local out = f:read("*a") or ""
    local ok, _, code = f:close()
    -- io.popen:close returns true on success; some Lua variants return additional values
    return true, (out:gsub("\n+$", ""))
end

return Shell
