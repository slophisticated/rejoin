local Logger = require("core.logger")
local File = require("utils.file")
local Config = require("core.config")
local Shell = require("utils.shell")

local AutoExecute = {}

-- Try to perform a su-backed copy into the app's data area (best-effort). This requires root and app-specific path knowledge.
-- format: cp src dest or su -c 'cp src dest'
local function trySuCopy(src, dest)
    -- Prefer direct cp if possible
    local cmd = string.format("cp '%s' '%s'", src, dest)
    local ok, out = pcall(function() return Shell.exec(cmd) end)
    if ok and out then
        return true
    end
    -- Try su wrapper
    local suCmd = string.format("su -c 'cp %s %s'", src, dest)
    local ok2, out2 = pcall(function() return Shell.exec(suCmd) end)
    if ok2 and out2 then
        return true
    end
    return false
end

-- Deploys the AutoExecute script to a deploy directory and returns the deployed path.
local function deployScriptForInstance(srcPath, instance)
    local conf = Config.get() or {}
    local deployBase = conf.autoExecuteDeployPath or "data/autoexecute"
    local pkg = instance and (instance.package or tostring(instance.id or "unknown")) or "unknown"
    -- sanitize package for filename
    local safePkg = pkg:gsub("[^%w%._-]", "_")
    local dest = string.format("%s/%s_AutoExecute.lua", deployBase, safePkg)
    local ok, err = File.copy(srcPath, dest)
    if not ok then return false, err end
    return true, dest
end

-- Inject AutoExecute script into an instance. This attempts to copy into app storage (root) if possible, otherwise deploys to a shared folder.
function AutoExecute.inject(instance)
    -- AutoExecute is global: instance path overrides, but the shared script is the default.
    local conf = Config.get() or {}
    local path = instance.autoExecutePath or (instance.autoExecute and instance.autoExecute.path) or conf.autoExecute
    if not path or path == "" then
        Logger.debug("AutoExecute: no script path provided for instance")
        return false, "no_script"
    end

    if not File.exists(path) then
        Logger.warn("AutoExecute: script not found: " .. tostring(path))
        return false, "not_found"
    end

    -- Try best-effort su copy into app data (placeholder path). The exact destination depends on the target package and installation.
    local appDestBase = conf.appAutoExecutePath or nil -- if set by user
    if appDestBase then
        local pkg = instance and instance.package or "unknown"
        local safePkg = pkg:gsub("[^%w%._-]", "_")
        local appDest = string.format("%s/%s_AutoExecute.lua", appDestBase, safePkg)
        local ok, _ = trySuCopy(path, appDest)
        if ok then
            Logger.info("AutoExecute: deployed script into app storage: " .. tostring(appDest))
            return true, appDest
        else
            Logger.debug("AutoExecute: su copy into app storage failed; falling back to deploy folder")
        end
    end

    -- Fallback: deploy script to shared deploy folder
    local ok2, deployedOrErr = deployScriptForInstance(path, instance)
    if not ok2 then
        Logger.error("AutoExecute: failed to deploy script: " .. tostring(deployedOrErr))
        return false, deployedOrErr
    end

    Logger.info("AutoExecute: deployed script to " .. tostring(deployedOrErr) .. ". (Manual in-app injection may be required)")
    return true, deployedOrErr
end

return AutoExecute
