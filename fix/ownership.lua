--@ module = true

--[====[

fix/ownership
=============

Fixes instances of dwarves claiming the same item

Sometimes multiple dwarves will claim the same item and this may lead to
the constant looping of the "Store owned item" job. This may show as a dwarf
repeatedly trying to put an item in their cabinet and they cant causing them
to keep picking it up and trying to put it in.

Usage:
fix/ownership
fix/ownership help

--]====]

-- Dwarf thinks they own the item but the item doesnt hold the proper
-- ref that actually makes this true
local function owner_not_recognized()
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        for index = #unit.owned_items-1, 0, -1 do
            local item = df.item.find(unit.owned_items[index])
            if not item then goto continue end

            for _, ref in ipairs(item.general_refs) do
                if df.general_ref_unit_itemownerst:is_instance(ref) then
                    -- make sure the ref belongs to unit
                    if ref.unit_id == unit.id then goto continue end
                end
            end
            print('Erasing ' .. dfhack.TranslateName(unit.name) .. ' claim on item #' .. item.id)
            unit.owned_items:erase(index)
            ::continue::
        end
    end
end

local args = {...}

if args[1] == "help" then
    print(dfhack.script_help())
    return
end

owner_not_recognized()
