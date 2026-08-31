local Logger = require("core.logger")
local Shell = require("utils.shell")

-- Auth / account-login detection.
--
-- Roblox for Android stores its session cookie in the WebView cookie database at
--   /data/data/<package>/app_webview/Default/Cookies
-- (a SQLite file). When an account is logged in, a `.ROBLOSECURITY` token row exists.
--
-- A clone that has NEVER been logged in either has no cookie DB yet or an empty one.
-- We use that to tell "not logged in" apart from "force-close stub": when a clone is
-- low-RSS AND not logged in, it is treated as idle and never force-relaunched.
--
-- The path is configurable per instance via `cookiePath` (App Cloner may move data).
-- Root is required to read the app's data directory (Shell.exec wraps with su).

local Auth = {}

local function defaultCookiePath(pkg)
    return "/data/data/" .. pkg .. "/app_webview/Default/Cookies"
end

local function resolvePath(instance)
    if instance and instance.cookiePath and instance.cookiePath ~= "" then
        return instance.cookiePath
    end
    if instance and instance.package then
        return defaultCookiePath(instance.package)
    end
    return nil
end

-- Returns:
--   true  -> an account is logged in (a session token is present)
--   false -> definitely NOT logged in (cookie DB missing, or no token stored)
--   nil   -> could not determine (e.g. root read failed). Callers fall back to the
--            restart-safe behavior (i.e. treat as logged in / relaunch normally).
function Auth.isLoggedIn(instance)
    local pkg = instance and instance.package
    if not pkg then return nil end
    local path = resolvePath(instance)
    if not path then return nil end

    -- 1) Does the cookie DB exist? A missing file means the app has never stored a
    --    session (never logged in).
    local existsCmd = string.format("[ -f '%s' ] && echo AE_EXISTS || echo AE_MISSING", path)
    local ok, out = pcall(function() return Shell.exec(existsCmd) end)
    if not ok or not out or out == "(dry-run)" then return nil end
    if out:find("AE_MISSING", 1, true) then
        return false
    end
    if not out:find("AE_EXISTS", 1, true) then
        -- no marker at all -> the root probe failed -> indeterminate
        return nil
    end

    -- 2) DB exists; look for the `.ROBLOSECURITY` token. It's a binary (SQLite) file,
    --    so use `grep -a`. `-c` prints a count (0 when absent) as long as the file can
    --    be read; empty output means the read itself failed -> indeterminate.
    local grepCmd = string.format("grep -a -c '.ROBLOSECURITY' '%s'", path)
    local ok2, out2 = pcall(function() return Shell.exec(grepCmd) end)
    if not ok2 or not out2 or out2 == "(dry-run)" then return nil end
    out2 = out2:gsub("%s+", "")
    if out2 == "" then return nil end
    local count = tonumber(out2)
    if not count then return nil end
    return count > 0
end

return Auth
