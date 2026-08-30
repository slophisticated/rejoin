-- Config template for Rejoin Engine
return {
    -- AutoExecute is GLOBAL: all instances share the same script.
    autoExecute = "data/autoexecute/sample_AutoExecute.lua",
    monitorInterval = 5,
    recoveryDelay = 3,
    recoveryRetries = 3,
    checkTimeout = 15,
    debug = true,
    -- Console log verbosity. Hidden below this level: "DEBUG" shows everything,
    -- "INFO" is the default (hides the monitor's per-probe/su debug spam).
    logLevel = "INFO",
    autoExecuteDeployPath = "data/autoexecute",
    logPath = "data/rejoin.log",
    -- Optional fast filter for auto-detect clone scan (e.g. "com.apengjers."). Empty = disabled.
    clonePackagePrefix = "",
    -- Seconds an app may stay frozen/stuck before the monitor force-relaunches it.
    freezeTimeout = 60,
    -- Seconds after launch that a running app is still considered "starting" before it
    -- is judged ingame vs stuck.
    gracePeriod = 30,
    -- Enable ANR (Application Not Responding) detection via logcat (best-effort, needs
    -- readable logcat, more reliable with root).
    anrCheckEnabled = true,
    -- Minimum resident memory (MB) for a clone's process to be considered ACTIVE.
    -- A running clone uses ~230 MB while a force-close stub is only ~7 MB, so anything
    -- below this is treated as "not really running" and gets relaunched. Tune if needed.
    minRss = 50,
    -- Timeout (seconds) for each shell command (via the `timeout` tool) so a hung
    -- su/dumpsys call can't freeze the whole tool / stop the terminal accepting input.
    shellTimeout = 10,
    -- Automatic per-cycle diagnostics: written to this file whenever the app is
    -- launched via Menu 1 (Launch + Monitor). Shows running/isActive/RSS per clone.
    launchLogPath = "launch.log",
    launchLogEnabled = true,

    -- "Launch All" launches clones ONE AT A TIME, waiting for each to reopen before
    -- starting the next (so floating-window clones each get a chance to appear).
    -- launchWaitInterval: how often (s) to poll for the process while waiting.
    -- launchWaitTimeout:   how long (s) to wait before giving up on one clone and moving on.
    -- launchSettleDelay:   extra pause (s) after a clone is detected, before launching next.
    launchWaitInterval = 3,
    -- How long (s) to wait for a clone to become ACTIVE (RSS >= minRss) during the
    -- Menu 1 sequential launch (Starting -> Running) before moving on to the next one.
    launchWaitTimeout = 60,
    launchSettleDelay = 5,
    -- Run shell commands as root (su -c). Required on a rooted device Android 11+ so that
    -- ps/pidof/pgrep can actually see the app processes the Monitor depends on; Termux run
    -- as a normal user cannot see other apps' processes. Set false on a non-root device.
    useRoot = true,
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
