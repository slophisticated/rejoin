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
    instances = {
        -- Example instance (AutoExecute is global; per-instance path is optional override)
        {
            id = 1,
            name = "Main",
            package = "com.roblox.client",
            privateServer = "roblox://your_server_id"
        }
    }
}
