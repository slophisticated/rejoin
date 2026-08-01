local InstanceManager = {}

local instances = {}

-- Load instances from provided config table
function InstanceManager.load(config)
    instances = {}
    if config and type(config.instances) == "table" then
        for _, v in ipairs(config.instances) do
            table.insert(instances, v)
        end
    end
end

function InstanceManager.getAll()
    return instances
end

function InstanceManager.count()
    return #instances
end

function InstanceManager.findById(id)
    for _, v in ipairs(instances) do
        if v.id == id then return v end
    end
    return nil
end

local function persist()
    local Config = require("core.config")
    local conf = Config.get() or {}
    conf.instances = instances
    return Config.save(conf)
end

function InstanceManager.add(instance)
    instance = instance or {}
    -- compute next id
    local maxid = 0
    for _, v in ipairs(instances) do
        if type(v.id) == "number" and v.id > maxid then maxid = v.id end
    end
    instance.id = (instance.id and tonumber(instance.id)) or (maxid + 1)

    table.insert(instances, instance)
    local ok, err = persist()
    if not ok then return false, err end
    return true, instance
end

function InstanceManager.update(id, updates)
    id = tonumber(id)
    local inst = InstanceManager.findById(id)
    if not inst then return false, "not_found" end
    for k, v in pairs(updates) do inst[k] = v end
    local ok, err = persist()
    if not ok then return false, err end
    return true, inst
end

function InstanceManager.remove(id)
    id = tonumber(id)
    for i, v in ipairs(instances) do
        if v.id == id then
            table.remove(instances, i)
            local ok, err = persist()
            if not ok then return false, err end
            return true
        end
    end
    return false, "not_found"
end

return InstanceManager