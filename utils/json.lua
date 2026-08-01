-- JSON helper: prefer cjson if available
local ok, cjson = pcall(require, "cjson")
local JSON = {}

if ok and cjson then
    function JSON.encode(t)
        return cjson.encode(t)
    end
    function JSON.decode(s)
        return cjson.decode(s)
    end
else
    -- Minimal fallback for simple tables using a very small encoder (not full-featured)
    function JSON.encode(t)
        error("JSON.encode: cjson not available; fallback encoder not implemented")
    end
    function JSON.decode(s)
        error("JSON.decode: cjson not available; fallback decoder not implemented")
    end
end

return JSON
