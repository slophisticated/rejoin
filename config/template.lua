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
    -- A running clone reads ~1 GB while a force-close stub is ~188 MB, so anything
    -- below this is treated as "not really running" and gets relaunched. Tune if needed.
    minRss = 300,
    -- Timeout (seconds) for each shell command (via the `timeout` tool) so a hung
    -- su/dumpsys call can't freeze the whole tool / stop the terminal accepting input.
    shellTimeout = 10,
    -- Automatic per-cycle diagnostics: written to this file whenever the app is
    -- launched via Menu 1 (Launch + Monitor). Shows running/isActive/RSS per clone.
    launchLogPath = "launch.log",
    launchLogEnabled = true,

    -- Deprioritize the Roblox clones with renice/ionice to cut RAM/CPU contention when
    -- several floating windows run at once. Applied to every clone after launch/recovery
    -- (the process gets a new pid on each relaunch, so tuning is re-applied each time).
    optimizer = {
        enabled = true,
        renice = 19,   -- CPU scheduling priority (higher = lower). 19 = lowest.
        ionice = 3,    -- I/O class: 0=none,1=realtime,2=best-effort,3=idle.
    },
    -- Auto-arrange the floating windows into a grid. See display.md (2x2: 1=TL,2=TR,
    -- 3=BL,4=BR). Because dumpsys doesn't list these clones, window rects are estimated
    -- from a default origin + relative drags; all geometry here is for on-device tuning.
    windowLayout = {
        enabled = true,
        cols = 2,
        rows = 2,
        marginPx = 20,
        cellGapPx = 12,
        handleInsetPx = 24,   -- distance of the resize handle from the window corner (px)
        titleGrabInsetY = 24, -- title-bar grab point below the window's top edge (px)
        moveSteps = 16,
        resizeSteps = 12,
        stepDelayMs = 30,
        -- defaultRect = {left,top,right,bottom}  -- set if the cold-start origin differs
        -- from full-screen, so relative drags land in the right quadrant.
    },

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
