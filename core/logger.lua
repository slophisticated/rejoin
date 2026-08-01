local Logger = {}

Logger.levels = {
    INFO = "INFO",
    WARN = "WARN",
    ERROR = "ERROR",
    DEBUG = "DEBUG"
}

local function getTime()
    return os.date("%H:%M:%S")
end

local FileUtil = require("utils.file")

local defaultLogPath = "data/rejoin.log"
local logFilePath = defaultLogPath

-- Try to read log path from config file without requiring core.config to avoid circular dependency.
-- This reads config/config.lua if present and extracts logPath field.
local function loadLogPathFromConfig()
    local confPath = "config/config.lua"
    if FileUtil.exists(confPath) then
        local ok, conf = pcall(dofile, confPath)
        if ok and type(conf) == "table" and conf.logPath then
            return tostring(conf.logPath)
        end
    end
    return nil
end

local function ensureLogDir()
    local dir = logFilePath:match("^(.*)[/\\]")
    if dir and dir ~= "" then
        pcall(function()
            -- try to use lfs or mkdir -p
            local lfs_ok, lfs = pcall(require, "lfs")
            if lfs_ok and lfs and lfs.mkdir then
                local cur = ""
                for part in dir:gmatch("[^/\\]+") do
                    cur = (cur == "") and part or (cur .. "/" .. part)
                    if lfs.attributes(cur) == nil then
                        pcall(lfs.mkdir, cur)
                    end
                end
            else
                os.execute("mkdir -p '" .. dir .. "'")
            end
        end)
    end
end

local function appendLogToFile(line)
    ensureLogDir()
    local f, err = io.open(logFilePath, "a")
    if not f then return false, err end
    f:write(line .. "\n")
    f:close()
    return true
end

-- initialize logFilePath from config if available
local fromConfig = loadLogPathFromConfig()
if fromConfig then logFilePath = fromConfig end

local function log(level, message)
    local line = string.format("[%s] [%s] %s", getTime(), level, tostring(message))
    print(line)
    pcall(function() appendLogToFile(line) end)
end

function Logger.info(message)
    log(Logger.levels.INFO, message)
end

function Logger.warn(message)
    log(Logger.levels.WARN, message)
end

function Logger.error(message)
    log(Logger.levels.ERROR, message)
end

function Logger.debug(message)
    log(Logger.levels.DEBUG, message)
end

function Logger.getLogPath()
    return logFilePath
end

function Logger.setLogPath(path)
    if path and type(path) == "string" and path ~= "" then
        logFilePath = path
    end
end

return Logger