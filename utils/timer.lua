local Logger = require("core.logger")
local Timer = {}

function Timer.sleep(seconds)
    seconds = tonumber(seconds) or 1
    -- Prefer luasocket if available
    local ok, socket = pcall(require, "socket")
    if ok and socket and socket.sleep then
        socket.sleep(seconds)
        return true
    end

    -- Fallback to os.execute sleep (Termux/Linux)
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
