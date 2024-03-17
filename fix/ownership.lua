--@ enable = true
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
enable fix/ownership
disable fix/ownership
fix/ownership now

--]====]

local GLOBAL_KEY = 'fix-ownership'

enabled = enabled or false

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

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {enabled=enabled})
end

local function event_loop()
    if enabled then
        owner_not_recognized()
        dfhack.timeout(1, 'days', event_loop)
    end
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        enabled = false
        return
    end

    if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
        return
    end

    local persisted_data = dfhack.persistent.getSiteData(GLOBAL_KEY, {enabled=false})
    enabled = persisted_data.enabled
    event_loop()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('fix/ownership only works in fortress mode')
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and 'enable' or 'disable'}
end

if args[1] == "enable" then
    enabled = true
elseif args[1] == "disable" then
    enabled = false
elseif args[1] == "now" then
    owner_not_recognized()
    print("Completed check")
    return
else
    local enabled_str = enabled and "enabled" or "disabled"
    print("fix/ownership is currently " .. enabled_str)
    return
end

event_loop()
persist_state()
