-- in-game dialog interface for the quickfort script
--[====[
gui/quickfort
=============
In-game dialog interface for the `quickfort` script.
]====]

local args = {...}

if #args == 0 then
    dfhack.run_script('quickfort', 'gui')
else
    dfhack.run_script('quickfort', table.unpack(args))
end
