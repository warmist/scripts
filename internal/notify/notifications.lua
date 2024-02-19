--@module = true

local gui = require('gui')
local json = require('json')
local list_agreements = reqscript('list-agreements')
local warn_stranded = reqscript('warn-stranded')

local CONFIG_FILE = 'dfhack-config/notify.json'

local caravans = df.global.plotinfo.caravans

local function get_active_depot()
    for _, bld in ipairs(df.global.world.buildings.other.TRADE_DEPOT) do
        if bld:getBuildStage() == bld:getMaxBuildStage() and
            (#bld.jobs == 0 or bld.jobs[0].job_type ~= df.job_type.DestroyBuilding)
        then
            return bld
        end
    end
end

local function for_agitated_creature(fn)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            unit.flags4.agitated_wilderness_creature
        then
            if fn(unit) then return end
        end
    end
end

local function for_invader(fn)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            dfhack.units.isInvader(unit) and
            not dfhack.units.isHidden(unit)
        then
            if fn(unit) then return end
        end
    end
end

local function for_hostile(fn)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not dfhack.units.isInvader(unit) and
            dfhack.units.isDanger(unit) and
            not dfhack.units.isFortControlled(unit) and
            not dfhack.units.isHidden(unit) and
            not unit.flags4.agitated_wilderness_creature
        then
            if fn(unit) then return end
        end
    end
end

local function is_in_dire_need(unit)
    return unit.counters2.hunger_timer > 75000 or
        unit.counters2.thirst_timer > 50000 or
        unit.counters2.sleepiness_timer > 150000
end

local function for_starving(fn)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            dfhack.units.isSane(unit) and
            dfhack.units.isFortControlled(unit) and
            is_in_dire_need(unit)
        then
            if fn(unit) then return end
        end
    end
end

local function for_moody(fn)
    for _, unit in ipairs(dfhack.units.getCitizens(false)) do
        local job = unit.job.current_job
        if job and df.job_type_class[df.job_type.attrs[job.job_type].type] == 'StrangeMood' then
            if fn(unit) then return end
        end
    end
end

local races = df.global.world.raws.creatures.all

local function is_stealer(unit)
    local casteFlags = races[unit.race].caste[unit.caste].flags
    if casteFlags.CURIOUS_BEAST_EATER or
        casteFlags.CURIOUS_BEAST_GUZZLER or
        casteFlags.CURIOUS_BEAST_ITEM
    then
        return true
    end
end

local function for_stealer(fn)
    for _, unit in ipairs(df.global.world.units.active) do
        if not dfhack.units.isDead(unit) and
            dfhack.units.isActive(unit) and
            not unit.flags1.caged and
            not dfhack.units.isHidden(unit) and
            not dfhack.units.isFortControlled(unit) and
            not unit.flags4.agitated_wilderness_creature and
            is_stealer(unit)
        then
            if fn(unit) then return end
        end
    end
end

local function count_units(for_fn, which)
    local count = 0
    for_fn(function() count = count + 1 end)
    if count > 0 then
        return ('%d %s%s %s on the map'):format(
            count,
            which,
            count == 1 and '' or 's',
            count == 1 and 'is' or 'are'
        )
    end
end

local function zoom_to_next(for_fn, state)
    local first_found, ret
    for_fn(function(unit)
        if not first_found then
            first_found = unit
        end
        if not state then
            dfhack.gui.revealInDwarfmodeMap(
                xyz2pos(dfhack.units.getPosition(unit)), true, true)
            ret = unit.id
            return true
        elseif unit.id == state then
            state = nil
        end
    end)
    if ret then return ret end
    if first_found then
        dfhack.gui.revealInDwarfmodeMap(
            xyz2pos(dfhack.units.getPosition(first_found)), true, true)
        return first_found.id
    end
end

local function get_stranded_message()
    local count = #warn_stranded.getStrandedGroups()
    if count > 0 then
        return ('%d group%s of citizens %s stranded'):format(
            count,
            count == 1 and '' or 's',
            count == 1 and 'is' or 'are'
        )
    end
end

-- the order of this list controls the order the notifications will appear in the overlay
NOTIFICATIONS_BY_IDX = {
    {
        name='traders_ready',
        desc='Notifies when traders are ready to trade at the depot.',
        fn=function()
            if #caravans == 0 then return end
            local num_ready = 0
            for _, car in ipairs(caravans) do
                if car.trade_state ~= df.caravan_state.T_trade_state.AtDepot then
                    goto skip
                end
                local car_civ = car.entity
                for _, unit in ipairs(df.global.world.units.active) do
                    if unit.civ_id ~= car_civ or not dfhack.units.isMerchant(unit) then
                        goto continue
                    end
                    for _, inv_item in ipairs(unit.inventory) do
                        if inv_item.item.flags.trader then
                            goto skip
                        end
                    end
                    ::continue::
                end
                num_ready = num_ready + 1
                ::skip::
            end
            if num_ready > 0 then
                return ('%d trader%s %s ready to trade'):format(
                    num_ready,
                    num_ready == 1 and '' or 's',
                    num_ready == 1 and 'is' or 'are'
                )
            end
        end,
        on_click=function()
            local bld = get_active_depot()
            if bld then
                dfhack.gui.revealInDwarfmodeMap(
                    xyz2pos(bld.centerx, bld.centery, bld.z), true, true)
            end
        end,
    },
    {
        name='mandates_expiring',
        desc='Notifies when a production mandate is within 1 month of expiring.',
        fn=function()
            local count = 0
            for _, mandate in ipairs(df.global.world.mandates) do
                if mandate.mode == df.mandate.T_mode.Make and
                    mandate.timeout_limit - mandate.timeout_counter < 2500
                then
                    count = count + 1
                end
            end
            if count > 0 then
                return ('%d production mandate%s near deadline'):format(
                    count,
                    count == 1 and '' or 's'
                )
            end
        end,
        on_click=function()
            gui.simulateInput(dfhack.gui.getDFViewscreen(), 'D_NOBLES')
        end,
    },
    {
        name='petitions_agreed',
        desc='Notifies when you have agreed to build (but have not yet built) a guildhall or temple.',
        fn=function()
            local t_agr, g_agr = list_agreements.get_fort_agreements(true)
            local sum = #t_agr + #g_agr
            if sum > 0 then
                return ('%d petition%s outstanding'):format(
                    sum, sum == 1 and '' or 's')
            end
        end,
        on_click=function() dfhack.run_script('gui/petitions') end,
    },
    {
        name='moody_status',
        desc='Describes the status of the current moody dwarf: gathering materials, working, or stuck',
        fn=function()
            local message
            for_moody(function(unit)
                local job = unit.job.current_job
                local bld = dfhack.job.getHolder(job)
                if not bld then
                    if dfhack.buildings.findAtTile(unit.path.dest) then
                        message = 'moody dwarf is claiming a workshop'
                    else
                        message = 'moody dwarf can\'t find needed workshop!'
                    end
                elseif job.flags.fetching or job.flags.bringing or
                    unit.path.goal == df.unit_path_goal.None
                then
                    message = 'moody dwarf is gathering items'
                elseif job.flags.working then
                    message = 'moody dwarf is working'
                else
                    message = 'moody dwarf can\'t find needed item!'
                end
                return true
            end)
            return message
        end,
        on_click=curry(zoom_to_next, for_moody),
    },
    {
        name='warn_starving',
        desc='Reports units that are dangerously hungry, thirsty, or drowsy.',
        fn=curry(count_units, for_starving, 'starving, dehydrated, or drowsy unit'),
        on_click=curry(zoom_to_next, for_starving),
    },
    {
        name='agitated_count',
        desc='Notifies when there are agitated animals on the map.',
        fn=curry(count_units, for_agitated_creature, 'agitated animal'),
        on_click=curry(zoom_to_next, for_agitated_creature),
    },
    {
        name='invader_count',
        desc='Notifies when there are active invaders on the map.',
        fn=curry(count_units, for_invader, 'invader'),
        on_click=curry(zoom_to_next, for_invader),
    },
    {
        name='hostile_count',
        desc='Notifies when there are non-invader hostiles (e.g. megabeasts) on the map.',
        fn=curry(count_units, for_hostile, 'non-invader hostile'),
        on_click=curry(zoom_to_next, for_hostile),
    },
    {
        name='warn_stealers',
        desc='Notifies when curious creatures enter the map that can steal your stuff.',
        fn=curry(count_units, for_stealer, 'item-stealing creature'),
        on_click=curry(zoom_to_next, for_stealer),
    },
    {
        name='warn_stranded',
        desc='Notifies when units are stranded from the main group.',
        fn=get_stranded_message,
        on_click=function() dfhack.run_script('warn-stranded') end,
    },
}

NOTIFICATIONS_BY_NAME = {}
for _, v in ipairs(NOTIFICATIONS_BY_IDX) do
    NOTIFICATIONS_BY_NAME[v.name] = v
end

local function get_config()
    local f = json.open(CONFIG_FILE)
    local updated = false
    if f.exists then
        -- remove unknown or out of date entries from the loaded config
        for k, v in pairs(f.data) do
            if not NOTIFICATIONS_BY_NAME[k] or NOTIFICATIONS_BY_NAME[k].version ~= v.version then
                updated = true
                f.data[k] = nil
            end
        end
    end
    for k, v in pairs(NOTIFICATIONS_BY_NAME) do
        if not f.data[k] or f.data[k].version ~= v.version then
            f.data[k] = {enabled=true, version=v.version}
            updated = true
        end
    end
    if updated then
        f:write()
    end
    return f
end

config = get_config()
