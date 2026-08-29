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
    -- Optional: if you want to attempt su-copy into app storage, set appAutoExecutePath to a writable path (requires root)
    -- appAutoExecutePath = "/data/data/<package>/files/autoexecute",
    instances = {
        {
            id = 1,
            name = "Main",
            package = "com.roblox.client",
            privateServer = "roblox://example_server_id"
        },
        {
            id = 2,
            name = "Clone1",
            package = "com.roblox.clone1",
            privateServer = nil
        }
    }
}
