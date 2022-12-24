-- makes units very speedy
--@ module = true
local help = [====[

superdwarf
==============
Similar to `fastdwarf`, per-creature.
Overrides units timers every game tick to 1, causing extremely fast actions

Usage:

Valid Options:

``-unit <id>``: Targets the unit with the specified ID.
                This is optional; if not specified, the selected unit is used instead.
                

``-help``:      Shows this help information


]====]

local repeatUtil = require('repeat-util')
local utils = require('utils')
local validArgs = utils.invert({
    'add',
    'del',
    'clear',
    'unit',
    'list',
    'help',
})
local args = utils.processArgs({...}, validArgs)


local id = "superdwarf"

superdwarfIds = {}

function MakeSuperdwarf(unit)
    repeatUtil.scheduleEvery(id, 1, 'ticks', function()
        if next(superdwarfIds) == nil then
            repeatUtil.cancel(id)
        else
            for _,v in pairs(superdwarfIds) do
                local unit = df.unit.find(v)
                if unit ~= nil and unit.flags1.inactive then
                    setActionTimers(unit, 1, df.unit_action_type.All)
                else
                    DeleteSuperdwarf(unit)
                end
            end
        end

    end)
end

function DeleteSuperdwarf(unit)
    local index = 0
    for k,v in pairs(superdwarfIds) do
        if v == unit.id then
            index = k
            break
        end
    end
    table.remove(superdwarfIds, index)
end

function ListSuperdwarfs()
    print("Current Superdwarfs: ")
    for k,v in pairs(superdwarfIds) do
        print(df.unit.find(v).name)
    end
end

function ClearSuperdwarfs()
    local count = #superdwarfIds
    for i=0, count do superdwarfIds[i]=nil end
end

function main(...)
    if args.help then 
        print(help)
        return
    end

    if args.clear then
        ClearSuperdwarfs()
        return
    end

    if args.list then
        ListSuperdwarfs()
        return
    end

    unit = nil

    if args.unit then
        local id = tonumber(args.unit)
        if id then
            unit = df.unit.find(id)
        else
            qerror("Invalid ID Provided")
        end
    else
        unit = dfhack.gui.getSelectedUnit()
    end

    if not unit then
        qerror("Invalid unit selection")
    end


    if args.add then
        AddSuperdwarf(unit)
    end

    if args.del then
        DeleteSuperdwarf(unit)
    end
end

if not dfhack_flags.module then
    main(...)
end