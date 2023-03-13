-- Suspend jobs

-- It can either suspend all jobs, or just jobs that risk blocking others.

local argparse = require('argparse')
local suspendmanagerUtils = reqscript('internal/suspendmanager/suspendmanager-utils')

local help, onlyblocking = false, false
argparse.processArgsGetopt(args, {
    {'h', 'help', handler=function() help = true end},
    {'b', 'onlyblocking', handler=function() onlyblocking = true end},
})

if help then
    print(dfhack.script_help())
    return
end

suspendmanagerUtils.foreach_construction_job(function (job)
    if not onlyblocking or suspendmanagerUtils.isBlocking(job) then
        suspendmanagerUtils.suspend(job)
    end
end)
