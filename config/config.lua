-- Sample config for Rejoin Engine (adjust package names and paths for your device)
return {
    autoExecute = "data/autoexecute/sample_AutoExecute.lua",
    monitorInterval = 5,
    recoveryDelay = 3,
    recoveryRetries = 3,
    checkTimeout = 15,
    debug = true,
    autoExecuteDeployPath = "data/autoexecute",
    logPath = "data/rejoin.log",
    -- Optional fast filter for auto-detect clone scan (e.g. "com.apengjers."). Empty = disabled.
    clonePackagePrefix = "",
    freezeTimeout = 60,
    gracePeriod = 30,
    anrCheckEnabled = true,
    -- Minimum resident memory (MB) for a clone's process to be considered ACTIVE.
    -- A running clone uses ~230 MB while a force-close stub is only ~7 MB, so anything
    -- below this is treated as "not really running" and gets relaunched. Tune if needed.
    minRss = 300,
    -- Timeout (seconds) for each shell command (via the `timeout` tool) so a hung
    -- su/dumpsys call can't freeze the whole tool / stop the terminal accepting input.
    shellTimeout = 10,
    -- How long (s) to wait for one clone to become active (RSS >= minRss) during the
    -- Menu 1 sequential launch before moving on to the next instance.
    launchWaitTimeout = 60,
    -- Automatic per-cycle diagnostics: written to this file whenever the app is
    -- launched via Menu 1 (Launch + Monitor). Shows running/isActive/RSS per clone.
    launchLogPath = "launch.log",
    launchLogEnabled = true,
    -- Optional: if you want to attempt su-copy into app storage, set appAutoExecutePath to a writable path (requires root)
    -- appAutoExecutePath = "/data/data/<package>/files/autoexecute",
    instances = {
        [1] = {
        id = 1,
        name = "Clone1",
        package = "com.apengjers.v3",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        },
        [2] = {
        id = 2,
        name = "Clone2",
        package = "com.apengjers.v4",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        },
        [3] = {
        id = 3,
        name = "Clone3",
        package = "com.apengjers.v5",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        },
        [4] = {
        id = 4,
        name = "Clone4",
        package = "com.apengjers.v6",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        },
    }
}