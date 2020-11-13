-- automate periodic running of the unsuspend script
--[====[

autounsuspend
=============
Periodically check construction jobs and keep them unsuspended with the
`unsuspend` script.
]====]

local job_name = '__autounsuspend'

local function help()
    print('syntax: autounsuspend [start|stop]')
end

local function stop()
    dfhack.run_command{'repeat', '-cancel', job_name}
    print('autounsuspend Stopped.')
end

local function start()
    dfhack.run_command{'repeat', '-name', job_name, '-time', '1',
                       '-timeUnits', 'days', '-command', '[', 'unsuspend', ']'}
    print('autounsuspend Running.')
end

local action_switch = {
    start=start,
    stop=stop,
}
setmetatable(action_switch, {__index=function() return help end})

local args = {...}
action_switch[table.remove(args, 1) or 'help']()
