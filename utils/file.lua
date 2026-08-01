local lfs_ok, lfs = pcall(require, "lfs")
local File = {}

local function ensureDirForPath(path)
    if not path then return end
    local dir = path:match("^(.*)[/\\]")
    if not dir or dir == "" then return end
    -- Try lfs.mkdir if available
    if lfs_ok and lfs and lfs.mkdir then
        -- create nested dirs
        local cur = ""
        for part in dir:gmatch("[^/\\]+") do
            cur = (cur == "") and part or (cur .. "/" .. part)
            if lfs.attributes(cur) == nil then
                pcall(lfs.mkdir, cur)
            end
        end
        return
    end
    -- Fallback to shell mkdir -p (Android/Termux/Linux)
    pcall(function() os.execute("mkdir -p '" .. dir .. "'") end)
end

function File.exists(path)
    if not path then return false end
    local f = io.open(path, "r")
    if f then f:close(); return true end
    return false
end

function File.read(path)
    local f = io.open(path, "r")
    if not f then return nil, "not_found" end
    local content = f:read("*a")
    f:close()
    return content
end

function File.write(path, content)
    ensureDirForPath(path)
    local f = io.open(path, "w")
    if not f then return false, "open_failed" end
    f:write(content)
    f:close()
    return true
end

function File.copy(src, dest)
    if not src or not dest then return false, "invalid_args" end
    local content, err = File.read(src)
    if not content then return false, err end
    ensureDirForPath(dest)
    return File.write(dest, content)
end

return File
