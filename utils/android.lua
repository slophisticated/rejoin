local Logger = require("core.logger")
local Shell = require("utils.shell")

local Android = {}

function Android.forceStop(packageName)
    Logger.info("Android: force stopping " .. tostring(packageName))
    Shell.exec(string.format("am force-stop %s", packageName))
end

function Android.launch(packageName)
    Logger.info("Android: launching " .. tostring(packageName))
    Shell.exec(string.format("am start -n %s/.MainActivity", packageName))
end

function Android.openURL(url)
    Logger.info("Android: opening URL " .. tostring(url))
    Shell.exec(string.format("am start -a android.intent.action.VIEW -d '%s'", url))
end

return Android
