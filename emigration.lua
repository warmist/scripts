--Allow stressed dwarves to emigrate from the fortress
-- For 34.11 by IndigoFenix; update and cleanup by PeridexisErrant
-- old version:  http://dffd.bay12games.com/file.php?id=8404
--@module = true
--@enable = true

local json = require('json')
local persist = require('persist-table')

local GLOBAL_KEY = 'emigration' -- used for state change hooks and persistence

enabled = enabled or false

function isEnabled()
    return enabled
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({enabled=enabled})
end

function desireToStay(unit,method,civ_id)
    -- on a percentage scale
    local value = 100 - unit.status.current_soul.personality.stress / 5000
    if method == 'merchant' or method == 'diplomat' then
        if civ_id ~= unit.civ_id then value = value*2 end end
    if method == 'wild' then
        value = value*5 end
    return value
end

function desert(u,method,civ)
    u.following = nil
    local line = dfhack.TranslateName(dfhack.units.getVisibleName(u)) .. " has "
    if method == 'merchant' then
        line = line.."joined the merchants"
        u.flags1.merchant = true
        u.civ_id = civ
    elseif method == 'diplomat' then
        line = line.."followed the diplomat"
        u.flags1.diplomat = true
        u.civ_id = civ
    else
        line = line.."abandoned the settlement in search of a better life."
        u.civ_id = -1
        u.flags1.forest = true
        u.animal.leave_countdown = 2
    end
    print(line)
    dfhack.gui.showAnnouncement(line, COLOR_WHITE)
end

function canLeave(unit)
    if not unit.status.current_soul then
        return false
    end

    for _, skill in pairs(unit.status.current_soul.skills) do
        if skill.rating > 14 then return false end
    end

    return dfhack.units.isOwnRace(unit) and  --  Doubtful check. naturalized citizens
           dfhack.units.isOwnCiv(unit) and   --  might also want to leave.
           dfhack.units.isActive(unit) and
           not dfhack.units.isOpposedToLife(unit) and
           not unit.flags1.merchant and
           not unit.flags1.diplomat and
           not unit.flags1.chained and
           dfhack.units.getNoblePositions(unit) == nil and
           unit.military.squad_id == -1 and
           dfhack.units.isCitizen(unit) and
           dfhack.units.isSane(unit) and
           not dfhack.units.isBaby(unit) and
           not dfhack.units.isChild(unit)
end

function checkForDeserters(method,civ_id)
    local allUnits = df.global.world.units.active
    for i=#allUnits-1,0,-1 do   -- search list in reverse
        local u = allUnits[i]
        if canLeave(u) and math.random(100) > desireToStay(u,method,civ_id) then
            desert(u,method,civ_id)
        end
    end
end

function checkmigrationnow()
    local merchant_civ_ids = {} --as:number[]
    local diplomat_civ_ids = {} --as:number[]
    local allUnits = df.global.world.units.active
    for i=0, #allUnits-1 do
        local unit = allUnits[i]
        if dfhack.units.isSane(unit)
        and dfhack.units.isActive(unit)
        and not dfhack.units.isOpposedToLife(unit)
        and not unit.flags1.tame
        then
            if unit.flags1.merchant then table.insert(merchant_civ_ids, unit.civ_id) end
            if unit.flags1.diplomat then table.insert(diplomat_civ_ids, unit.civ_id) end
        end
    end

    for _, civ_id in pairs(merchant_civ_ids) do checkForDeserters('merchant', civ_id) end
    for _, civ_id in pairs(diplomat_civ_ids) do checkForDeserters('diplomat', civ_id) end
    checkForDeserters('wild', -1)
end

local function event_loop()
    if enabled then
        checkmigrationnow()
        dfhack.timeout(1, 'months', event_loop)
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

    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    enabled = (persisted_data or {enabled=false})['enabled']
    event_loop()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('emigration needs a loaded fortress map to work')
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
else
    return
end

event_loop()
persist_state()
