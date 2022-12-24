-- makes units very speedy
--@ module = true
local repeatUtil = require('repeat-util')
local commandArg = ({...})[1]

local superId = "superdwarf"

superdwarfIds = superdwarfIds or {}

function AddSuperdwarf(unit)
    if superdwarfIds[unit.id] then
        qerror("Dwarf is already super!")
    end
    superdwarfIds[unit.id] = true
    repeatUtil.scheduleEvery(superId, 1, 'ticks', function()
        if next(superdwarfIds) == nil then
            repeatUtil.cancel(superId)
        else
            for k,_ in pairs(superdwarfIds) do
                local unit = df.unit.find(k)
                if unit ~= nil and not unit.flags1.inactive then
                    dfhack.units.setGroupActionTimers(unit, 1, df.unit_action_type_group.All)
                else
                    DeleteSuperdwarf(unit)
                end
            end
        end

    end)
end

function DeleteSuperdwarf(unit)
    if superdwarfIds[unit.id] then
        superdwarfIds[unit.id] = nil
    else
        qerror("Dwarf was not already super")
    end
    superdwarfIds[unit.id] = nil
end

function ListSuperdwarfs()
    print("Current Superdwarfs: ")
    for k,_ in pairs(superdwarfIds) do
        print("[" .. k .. "] " .. dfhack.TranslateName(df.unit.find(k).name))
    end
end

function ClearSuperdwarfs()
    for k,_ in pairs(superdwarfIds) do superdwarfIds[k] = nil end
end

function main(argCommand)
    if argCommand == 'clear' then
        ClearSuperdwarfs()
        print("Cleared Superdwarfs")
        return
    end

    if argCommand == 'list' then
        ListSuperdwarfs()
        return
    end

    local unit = dfhack.gui.getSelectedUnit()
    if not unit then
        qerror("Invalid unit selection")
        return
    end

    if argCommand == 'add' then
        AddSuperdwarf(unit)
        print("Applying superdwarf to [" .. unit.id .. "] " .. dfhack.TranslateName(unit.name))
        return
    end

    if argCommand == 'del' then
        DeleteSuperdwarf(unit)
        print("Removing superdwarf from [" .. unit.id .. "] " .. dfhack.TranslateName(unit.name))
        return
    end

    print(dfhack.script_help())
end

if not dfhack_flags.module then
    main(commandArg)
end
