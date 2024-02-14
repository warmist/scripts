--@module = true

local json = require('json')
local list_agreements = reqscript('list-agreements')

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

NOTIFICATIONS_BY_IDX = {
    {
        name='traders_ready',
        desc='Notifies when traders are ready to trade at the depot.',
        fn=function()
            if #caravans == 0 then return end
            local bld = get_active_depot()
            if not bld then return end
            local trader_goods_in_depot = {}
            for _, contained_item in ipairs(bld.contained_items) do
                local item = contained_item.item
                if item.flags.trader then
                    trader_goods_in_depot[item.id] = true
                    for _, binned_item in ipairs(dfhack.items.getContainedItems(item)) do
                        if binned_item.flags.trader then
                            trader_goods_in_depot[binned_item.id] = true
                        end
                    end
                end
            end
            local num_ready = 0
            for _, car in ipairs(caravans) do
                for _, item_id in ipairs(car.goods) do
                    local item = df.item.find(item_id)
                    if item and item.flags.trader and
                        not trader_goods_in_depot[item_id]
                    then
                        print('trader item not found: ', item_id)
                        goto skip
                    end
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
