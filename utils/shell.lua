local Logger = require("core.logger")
local Runtime = require("core.runtime")

local Shell = {}

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

    Logger.debug("Shell.exec: " .. cmd)
    local f = io.popen(cmd .. " 2>&1")
    if not f then return false, "popen_failed" end
    local out = f:read("*a") or ""
    local ok, _, code = f:close()
    -- io.popen:close returns true on success; some Lua variants return additional values
    return true, (out:gsub("\n+$", ""))
end

return Shell
