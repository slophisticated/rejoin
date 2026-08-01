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

return Timer
