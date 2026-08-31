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

-- List file names (optionally filtered by extension) inside a directory.
-- Returns a table of names (sorted), or nil on failure. Uses lfs when available,
-- falling back to a shell `ls` (works on Termux/Android).
function File.listDir(path, ext)
    if not path or path == "" then return nil, "no_dir" end
    local names = {}
    if lfs_ok and lfs and lfs.dir then
        local ok, it, state = pcall(lfs.dir, path)
        if ok and it then
            for name in it, state do
                if name ~= "." and name ~= ".." then
                    if not ext or name:sub(-#ext - 1) == "." .. ext then
                        table.insert(names, name)
                    end
                end
            end
            table.sort(names)
            return names
        end
        return nil, "lfs_dir_failed"
    end
    -- Fallback: shell ls with the extension filter.
    local okc, out = pcall(function()
        local cmd = string.format("ls -1 '%s' 2>/dev/null", path)
        if ext then cmd = string.format("ls -1 '%s'/*.%s 2>/dev/null", path, ext) end
        local f = io.popen(cmd)
        if not f then return "" end
        local s = f:read("*a") or ""
        f:close()
        return s
    end)
    if not okc then return nil, "ls_failed" end
    for line in (out or ""):gmatch("[^\r\n]+") do
        if line ~= "" then
            local base = line:match("([^/\\]+)$")
            if base then table.insert(names, base) end
        end
    end
    table.sort(names)
    return names
end

return File
