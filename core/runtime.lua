local Runtime = {}
Runtime.dryRun = false

function Runtime.setDryRun(v)
    Runtime.dryRun = v and true or false
end

function Runtime.isDryRun()
    return Runtime.dryRun
end

return Runtime
