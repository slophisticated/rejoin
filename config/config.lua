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
    freezeTimeout = 300,
    gracePeriod = 30,
    anrCheckEnabled = true,
    -- Optional: if you want to attempt su-copy into app storage, set appAutoExecutePath to a writable path (requires root)
    -- appAutoExecutePath = "/data/data/<package>/files/autoexecute",
    instances = {

    }
}
