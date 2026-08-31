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

    -- Fallback to os.execute sleep (Termux/Linux). With a lua-posix SIGINT handler
    -- installed, `system()` only delays the signal by at most the current chunk
    -- (<=0.25s in sleepInterruptible), so Ctrl+C still stops the monitor quickly.
    -- NOTE: do NOT use a busy-wait (os.clock) here — it pins a core at 100% CPU the
    -- whole time and makes the device hot/unresponsive (and does NOT fix Ctrl+C,
    -- which needs the lua-posix handler, not just non-blocked signals).
    os.execute("sleep " .. tostring(seconds))
    return true
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
