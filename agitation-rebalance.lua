--@module = true
--@enable = true

local eventful = require('eventful')

local GLOBAL_KEY = dfhack.current_script_name()

local function get_default_state()
    return {
        enabled=false,
        features={
            auto_preset=true,
            surface=true,
            cavern=true,
            cap_invaders=true,
        },
        thresholds={},
    }
end

state = state or get_default_state()
delay_frame_counter = delay_frame_counter or 0

function isEnabled()
    return state.enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, state)
end

local function is_agitated(unit)
    return unit and unit.flags4.agitated_wilderness_creature
end

local custom_difficulty = df.global.plotinfo.main.custom_difficulty
local function reset_surface_agitation()
    df.global.plotinfo.outdoor_irritation = custom_difficulty.wild_irritate_min
end

local function get_cavern_layer(unit)
end

-- if we're at our max invader count, pre-emptively destroy pending invaders
-- in units.all that aren't yet in units.active
local function cull_cavern_invaders(cavern_layer)
    if not cavern_layer then return end
end

local function check_new_unit(unit_id)
    -- when re-enabling at game load, ignore the first batch of units so we
    -- don't consider existing agitated units or cavern invaders as "new"
    if not delay_frame_counter then
        delay_frame_counter = df.global.world.frame_counter
        return
    elseif delay_frame_counter >= df.global.world.frame_counter then
        return
    end
    local unit = df.unit.find(unit_id)
    if is_agitated(unit) then
        reset_surface_agitation()
        return
    end
    local cavern_layer = get_cavern_layer(unit)
    cull_cavern_invaders(cavern_layer)
end

local function do_enable()
    state.enabled = true
    delay_frame_counter = 0
    eventful.enableEvent(eventful.eventType.UNIT_NEW_ACTIVE, 5)
    eventful.onUnitNewActive[GLOBAL_KEY] = check_new_unit
end

local function do_disable()
    state.disabled = true
    eventful.onUnitNewActive[GLOBAL_KEY] = nil
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_UNLOADED then
        do_disable()
        return
    end

    if sc ~= SC_MAP_LOADED or not dfhack.world.isFortressMode() then
        return
    end

    state = dfhack.persistent.getSiteData(GLOBAL_KEY, get_default_state())

    if state.enabled then
        do_enable()
        delay_frame_counter = nil
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    dfhack.printerr(GLOBAL_KEY .. ' needs a loaded fortress map to work')
    return
end

local args = {...}
local command = args[1]

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
    end
elseif command == 'preset' then
    print('TODO: preset')
elseif command == 'enable' then
    print('TODO: enable feature')
elseif command == 'disable' then
    print('TODO: disable feature')
elseif not command or command == 'status' then
    print(GLOBAL_KEY .. ' is ' .. (state.enabled and 'enabled' or 'not enabled'))
    print()
    print('TODO: status and state')
    return
else
    print(dfhack.script_help())
    return
end

persist_state()
