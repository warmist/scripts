-- Automate periodic running of the unsuspend script
--@module = true
--@enable = true

local json = require('json')
local persist = require('persist-table')

local GLOBAL_KEY = 'autounsuspend' -- used for state change hooks and persistence

enabled = enabled or false

function isEnabled()
    return enabled
end

local function persist_state()
    persist.GlobalTable[GLOBAL_KEY] = json.encode({enabled=enabled})
end

local function event_loop()
    if enabled then
        dfhack.run_script('unsuspend')
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

    local persisted_data = json.decode(persist.GlobalTable[GLOBAL_KEY] or '')
    enabled = (persisted_data or {enabled=false})['enabled']
    event_loop()
end

if dfhack_flags.module then
    return
end

if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
    dfhack.printerr('autounsuspend needs a loaded fortress map to work')
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    args = {dfhack_flags.enable_state and 'enable' or 'disable'}
end

local command = args[1]
if command == "enable" then
    enabled = true
elseif command == "disable" then
    enabled = false
else
    return
end

event_loop()
persist_state()
