--@module = true
--@enable = true

local eventful = require('plugins.eventful')
local exterminate = reqscript('exterminate')
local utils = require('utils')

local GLOBAL_KEY = dfhack.current_script_name()

local presets = {
    casual={
        wild_sens=100000,
        wild_irritate_min=0,
        wild_irritate_decay=100000,
        cavern_dweller_max_attackers=0,
    },
    lenient={
        wild_sens=10000,
        wild_irritate_min=7500,
        wild_irritate_decay=5000,
        cavern_dweller_max_attackers=20,
    },
    strict={
        wild_sens=1000,
        wild_irritate_min=500,
        wild_irritate_decay=1000,
        cavern_dweller_max_attackers=100,
    },
    insane={
        wild_sens=500,
        wild_irritate_min=400,
        wild_irritate_decay=100,
        cavern_dweller_max_attackers=500,
    },
}

local vanilla_presets = {
    casual={
        wild_sens=10000,
        wild_irritate_min=2000,
        wild_irritate_decay=500,
        cavern_dweller_max_attackers=0,
    },
    lenient={
        wild_sens=10000,
        wild_irritate_min=2000,
        wild_irritate_decay=500,
        cavern_dweller_max_attackers=50,
    },
    strict={
        wild_sens=10000,
        wild_irritate_min=0,
        wild_irritate_decay=100,
        cavern_dweller_max_attackers=75,
    },
}

local function get_default_state()
    return {
        enabled=false,
        features={
            auto_preset=true,
            surface=true,
            cavern=true,
            cap_invaders=true,
        },
        caverns={
            Cavern1={invasion_id=-1, threshold=0},
            Cavern2={invasion_id=-1, threshold=0},
            Cavern3={invasion_id=-1, threshold=0},
        },
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

local world = df.global.world
local map_features = world.features.map_features
local plotinfo = df.global.plotinfo
local custom_difficulty = plotinfo.main.custom_difficulty

local function reset_surface_agitation()
    plotinfo.outdoor_irritation = custom_difficulty.wild_irritate_min
end

local function is_cavern_invader(unit)
    if unit.invasion_id == -1 then
        return false
    end
    local invasion = df.invasion_info.find(unit.invasion_id)
    return invasion and invasion.origin_master_army_controller_id == -1
end

local function get_embark_tile_idx(pos)
    local x = pos.x // 48
    local y = pos.y // 48
    local site = dfhack.world.getCurrentSite()
    local rgn_height = site.rgn_max_y - site.rgn_min_y + 1
    return y + x*rgn_height
end

local function get_feature_data(unit)
    local pos = xyz2pos(dfhack.units.getPosition(unit))
    for _, map_feature in ipairs(map_features) do
        if not df.feature_init_subterranean_from_layerst:is_instance(map_feature) then
            goto continue
        end
        local idx = get_embark_tile_idx(pos)
        if pos.z >= map_feature.feature.min_map_z[idx] and
            pos.z <= map_feature.feature.max_map_z[idx]
        then
            return map_feature.start_depth, map_feature.feature.irritation_level
        end
        ::continue::
    end
end

local function is_unkilled(unit)
    return not dfhack.units.isKilled(unit) and
        unit.animal.vanish_countdown <= 0  -- not yet exterminated
end

function get_cavern_invaders()
    local invaders = {}
    for _, unit in ipairs(world.units.active) do
        if is_unkilled(unit) and is_cavern_invader(unit) then
            table.insert(invaders, unit)
        end
    end
    return invaders
end

local function get_agitated_units()
    local agitators = {}
    for _, unit in ipairs(world.units.active) do
        if is_unkilled(unit) and is_agitated(unit) then
            table.insert(agitators, unit)
        end
    end
    return agitators
end

-- if we're at our max invader count, pre-emptively destroy pending invaders
local function cull_pending_cavern_invaders(start_unit, num_to_cull)
    local culling = false
    for _, unit in ipairs(world.units.active) do
        if unit == start_unit then
            culling = true
        end
        if num_to_cull then
            if num_to_cull <= 0 then break end
            num_to_cull = num_to_cull - 1
        end
        if culling and is_cavern_invader(unit) then
            dfhack.printerr(('culling cavern invader %d (%s)'):format(unit.id, dfhack.units.getReadableName(unit)))
            exterminate.killUnit(unit, exterminate.killMethod.DISINTEGRATE)
        end
    end
end

local function check_new_unit(unit_id)
    -- when re-enabling at game load, ignore the first batch of units so we
    -- don't consider existing agitated units or cavern invaders as "new"
    if not delay_frame_counter then
        delay_frame_counter = world.frame_counter
        return
    elseif delay_frame_counter >= world.frame_counter then
        return
    end
    local unit = df.unit.find(unit_id)
    if not unit or not is_unkilled(unit) then return end
    if is_agitated(unit) or is_cavern_invader(unit) then
        dfhack.printerr(('unit %d (%s) entered map; agitated=%s, cavern=%s'):format(
            unit.id, dfhack.units.getReadableName(unit),
            is_agitated(unit), is_cavern_invader(unit)))
    else
        print(('unit %d (%s) entered map; agitated=%s, cavern=%s'):format(
            unit.id, dfhack.units.getReadableName(unit),
            is_agitated(unit), is_cavern_invader(unit)))
    end
    if state.features.surface and is_agitated(unit) then
        dfhack.printerr('adjusting surface irritation')
        reset_surface_agitation()
        return
    end
    if not state.features.cavern and
        not state.features.cap_invaders or
        not is_cavern_invader(unit)
    then
        return
    end
    if state.features.cap_invaders then
        local num_to_cull = custom_difficulty.cavern_dweller_max_attackers - #get_cavern_invaders()
        if num_to_cull > 0 then
            dfhack.printerr('active invaders above threshold')
            cull_pending_cavern_invaders(unit, num_to_cull)
            return
        end
    end
    if state.features.cavern then
        local cavern_layer, irritation = get_feature_data(unit)
        if not cavern_layer then return end
        dfhack.printerr('detected invader in cavern layer ' .. df.layer_type[cavern_layer])
        local cavern = state.caverns[df.layer_type[cavern_layer]]
        if cavern.invasion_id == unit.invasion_id then
            dfhack.printerr('invader part of current invasion; allow entry')
            return
        end
        if irritation < cavern.threshold then
            dfhack.printerr('not ready for next attack; killing cavern invaders')
            cull_pending_cavern_invaders(unit)
        else
            dfhack.printerr(('new cavern invasion detected: %d'):format(unit.invasion_id))
            cavern.invasion_id = unit.invasion_id
            cavern.threshold = irritation + (custom_difficulty.wild_sens-custom_difficulty.wild_irritate_min)
            persist_state()
        end
    end
end

local function do_preset(preset_name)
    local preset = presets[preset_name]
    if not preset then
        qerror('preset not found: ' .. preset_name)
    end
    utils.assign(custom_difficulty, preset)
    print('agitation-rebalance preset applied: ' .. preset_name)
end

local function do_enable()
    state.enabled = true
    delay_frame_counter = 0
    eventful.enableEvent(eventful.eventType.UNIT_NEW_ACTIVE, 5)
    eventful.onUnitNewActive[GLOBAL_KEY] = check_new_unit
    if not state.features.auto_preset then return end
    for preset_name,vanilla_settings in pairs(vanilla_presets) do
        local matched = true
        for k,v in pairs(vanilla_settings) do
            if custom_difficulty[k] ~= v then
                matched = false
                break
            end
        end
        if matched then
            do_preset(preset_name)
            break
        end
    end
end

local function do_disable()
    state.enabled = false
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
local command = table.remove(args, 1)

if dfhack_flags and dfhack_flags.enable then
    if dfhack_flags.enable_state then
        do_enable()
    else
        do_disable()
    end
elseif command == 'preset' then
    do_preset(args[1])
elseif command == 'enable' then
    local feature = state.features[args[1]]
    if feature == nil then
        qerror('feature not found: ' .. feature)
    end
    state.features[args[1]] = true
    print('feature enabled: ' .. feature)
elseif command == 'disable' then
    local feature = state.features[args[1]]
    if feature == nil then
        qerror('feature not found: ' .. feature)
    end
    state.features[args[1]] = false
    print('feature disabled: ' .. feature)
elseif not command or command == 'status' then
    print(GLOBAL_KEY .. ' is ' .. (state.enabled and 'enabled' or 'not enabled'))
    print()
    print('features:')
    for k,v in pairs(state.features) do
        print(('  %15s: %s'):format(k, v))
    end
    print()
    print('difficulty settings:')
    print(('            Wilderness sensitivity: %d (about %d tree(s) before initial attack)'):format(
        custom_difficulty.wild_sens, custom_difficulty.wild_sens // 100))
    print(('     Wilderness irritation minimum: %d (about %d tree(s) between attacks)'):format(
        custom_difficulty.wild_irritate_min,
        (custom_difficulty.wild_sens-custom_difficulty.wild_irritate_min) // 100))
    print(('       Wilderness irritation decay: %d (about %d additional tree(s) allowed per year)'):format(
        custom_difficulty.wild_irritate_decay, custom_difficulty.wild_irritate_decay // 100))
    print(('  Cavern dweller maximum attackers: %d'):format(
        custom_difficulty.cavern_dweller_max_attackers))
    print()
    local unhidden_invaders = {}
    for _, unit in ipairs(get_cavern_invaders()) do
        if not dfhack.units.isHidden(unit) then
            table.insert(unhidden_invaders, unit)
        end
    end
    print(('Current agitated wildlife:     %5d'):format(#get_agitated_units()))
    print(('Current known cavern invaders: %5d'):format(#unhidden_invaders))
    return
else
    print(dfhack.script_help())
    return
end

persist_state()
