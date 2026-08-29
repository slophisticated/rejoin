-- Config template for Rejoin Engine
return {
    -- AutoExecute is GLOBAL: all instances share the same script.
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
    -- Seconds an app may stay frozen/stuck before the monitor force-relaunches it.
    freezeTimeout = 300,
    -- Seconds after launch that a running app is still considered "starting" before it
    -- is judged ingame vs stuck.
    gracePeriod = 30,
    -- Enable ANR (Application Not Responding) detection via logcat (best-effort, needs
    -- readable logcat, more reliable with root).
    anrCheckEnabled = true,

    -- "Launch All" launches clones ONE AT A TIME, waiting for each to reopen before
    -- starting the next (so floating-window clones each get a chance to appear).
    -- launchWaitInterval: how often (s) to poll for the process while waiting.
    -- launchWaitTimeout:   how long (s) to wait before giving up on one clone and moving on.
    -- launchSettleDelay:   extra pause (s) after a clone is detected, before launching next.
    launchWaitInterval = 3,
    launchWaitTimeout = 90,
    launchSettleDelay = 5,
    instances = {
        -- Example instance (AutoExecute is global; per-instance path is optional override)
        -- privateServer accepts either a public game link
        --   https://www.roblox.com/games/<placeId>/...
        -- or a private server share link
        --   https://www.roblox.com/share?code=...&type=Server
        {
            id = 1,
            name = "Main",
            package = "com.roblox.client",
            privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg"
        }
    }
}
