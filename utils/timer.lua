local Logger = require("core.logger")
local Timer = {}

function Timer.sleep(seconds)
    seconds = tonumber(seconds) or 1
    -- Prefer luasocket if available (native, and does not block signal delivery).
    local ok, socket = pcall(require, "socket")
    if ok and socket and socket.sleep then
        socket.sleep(seconds)
        return true
    end

    -- Fallback: BUSY-WAIT on os.clock() instead of `os.execute("sleep")`.
    --
    -- Do NOT use os.execute("sleep ..."): POSIX system() BLOCKS SIGINT/SIGQUIT while
    -- the child runs, so Ctrl+C (SIGINT) never reaches the Lua process while we are
    -- waiting -> the monitor looks like it can't be stopped. A busy-wait loop never
    -- blocks signals, so Ctrl+C is delivered immediately (default action kills the
    -- program, or a lua-posix handler runs right away). Cost: a little CPU spin for
    -- the duration of the sleep.
    if seconds then
        local t0 = os.clock()
        while (os.clock() - t0) < seconds do
            -- spin; keeps signal delivery unblocked
        end
        return true
    end
    return false
end

-- Sleep in small steps so a SIGINT handler (that flips isStopped to true) can break
-- out quickly instead of waiting out the full interval. isStopped is a function
-- returning true to abort early.
function Timer.sleepInterruptible(seconds, isStopped)
    seconds = tonumber(seconds) or 1
    local step = 0.25
    local elapsed = 0
    while elapsed < seconds do
        if isStopped and isStopped() then
            return false
        end
        local chunk = math.min(step, seconds - elapsed)
        Timer.sleep(chunk)
        elapsed = elapsed + chunk
    end
    return not (isStopped and isStopped())
end

return Timer
