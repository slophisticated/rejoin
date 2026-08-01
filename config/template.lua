-- Config template for Rejoin Engine
return {
    autoExecute = "",
    monitorInterval = 5,
    recoveryDelay = 3,
    recoveryRetries = 3,
    checkTimeout = 15,
    debug = true,
    autoExecuteDeployPath = "data/autoexecute",
    logPath = "data/rejoin.log",
    instances = {
        -- Example instance
        {
            id = 1,
            name = "Main",
            package = "com.roblox.client",
            privateServer = "roblox://your_server_id",
            autoExecutePath = "/path/to/AutoExecute.lua"
        }
    }
}
