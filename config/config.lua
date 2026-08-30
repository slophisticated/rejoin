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
    -- A running clone reads ~1 GB while a force-close stub is ~188 MB, so anything
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
        -- defaultRect = {left,top,right,bottom}  -- set to the window's actual default
        -- rectangle if the cold-start origin differs from full-screen.
    },
    -- Optional: if you want to attempt su-copy into app storage, set appAutoExecutePath to a writable path (requires root)
    -- appAutoExecutePath = "/data/data/<package>/files/autoexecute",
    instances = {
        [1] = {
        id = 1,
        name = "Clone1",
        package = "com.apengjers.v3",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        grid = { col = 1, row = 1 },
        },
        [2] = {
        id = 2,
        name = "Clone2",
        package = "com.apengjers.v4",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        grid = { col = 2, row = 1 },
        },
        [3] = {
        id = 3,
        name = "Clone3",
        package = "com.apengjers.v5",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        grid = { col = 1, row = 2 },
        },
        [4] = {
        id = 4,
        name = "Clone4",
        package = "com.apengjers.v6",
        privateServer = "https://www.roblox.com/games/107778070777162/Steal-An-Egg",
        grid = { col = 2, row = 2 },
        },
    }
}