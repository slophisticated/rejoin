local File = require("utils.file")
local Logger = require("core.logger")

local Config = {}
local configPath = "config/config.lua"
local templatePath = "config/template.lua"
local data = nil

local function loadFromFile(path)
    if not File.exists(path) then return nil end
    local ok, conf = pcall(dofile, path)
    if ok and type(conf) == "table" then
        return conf
    end
    return nil
end

-- Initialize config from config/config.lua, fallback to template
data = loadFromFile(configPath) or loadFromFile(templatePath) or {}

function Config.get()
    return data
end

-- Serialize simple Lua table to a Lua file that returns the table
local function serializeTable(t, indent)
    indent = indent or ""
    local parts = {"{\n"}
    local nextIndent = indent .. "  "
    for k, v in pairs(t) do
        local key
        if type(k) == "string" and k:match("^[%a_][%w_]*$") then
            key = k .. " = "
        else
            key = "[" .. string.format('%q', tostring(k)) .. "] = "
        end

        local val
        local tp = type(v)
        if tp == "string" then
            val = string.format('%q', v)
        elseif tp == "number" or tp == "boolean" then
            val = tostring(v)
        elseif tp == "table" then
            val = serializeTable(v, nextIndent)
        else
            val = "nil"
        end

        table.insert(parts, nextIndent .. key .. val .. ",\n")
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts)
end

function Config.save(conf)
    conf = conf or data
    local contents = "return " .. serializeTable(conf) .. "\n"
    local ok, err = File.write(configPath, contents)
    if not ok then
        Logger.error("Config.save: failed to write config: " .. tostring(err))
        return false, err
    end
    data = conf
    Logger.info("Config: saved configuration to " .. configPath)
    return true
end

function Config.resetToTemplate()
    local tpl = loadFromFile(templatePath)
    if not tpl then
        return false, "no_template"
    end
    return Config.save(tpl)
end

return Config