-- Prevents a "loyalty cascade" when a citizens are killed.

local function fixUnit(unit)
    local fixed = false

    if not dfhack.units.isOwnCiv(unit) or not dfhack.units.isDwarf(unit) then
        return fixed
    end

    local unit_entity_links = df.global.world.history.figures[unit.hist_figure_id].entity_links
    local unit_former_member_index = nil
    local unit_enemy_member_index = nil

    for index, link in pairs(unit_entity_links) do
        local link_type = link:getType()

        if link_type ==  df.histfig_entity_link_type.FORMER_MEMBER and link.entity_id == df.global.plotinfo.civ_id then
            unit_former_member_index = index
        end

        if link_type ==  df.histfig_entity_link_type.ENEMY and link.entity_id == df.global.plotinfo.civ_id then
            unit_enemy_member_index = index
        end
    end

    -- If the unit is a former member of your civilization, as well as now an
    -- enemy of it, we make it become a member again.
    if unit_former_member_index and unit_enemy_member_index then
        local unit_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
        local civ_name = dfhack.TranslateName(df.global.world.entities.all[df.global.plotinfo.civ_id].name)

        if unit_former_member_index > unit_enemy_member_index then
            unit_former_member_index, unit_enemy_member_index = unit_enemy_member_index, unit_former_member_index
        end

        unit_entity_links:erase(unit_enemy_member_index)
        unit_entity_links:erase(unit_former_member_index)
        unit_entity_links:insert('#', df.histfig_entity_link_memberst{entity_id = df.global.plotinfo.civ_id, link_strength = 100})

        dfhack.gui.showAnnouncement(([[loyaltycascade: %s is now a member of %s again]]):format(unit_name, civ_name), COLOR_WHITE)

        fixed = true
    end

    for index, link in pairs(unit_entity_links) do
        local link_type = link:getType()

        if link_type ==  df.histfig_entity_link_type.FORMER_MEMBER and link.entity_id == df.global.plotinfo.group_id then
            unit_former_member_index = index
        end

        if link_type ==  df.histfig_entity_link_type.ENEMY and link.entity_id == df.global.plotinfo.group_id then
            unit_enemy_member_index = index
        end
    end

    if unit_former_member_index and unit_enemy_member_index then
        local unit_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
        local group_name = dfhack.TranslateName(df.global.world.entities.all[df.global.plotinfo.group_id].name)

        if unit_former_member_index > unit_enemy_member_index then
            unit_former_member_index, unit_enemy_member_index = unit_enemy_member_index, unit_former_member_index
        end

        unit_entity_links:erase(unit_enemy_member_index)
        unit_entity_links:erase(unit_former_member_index)
        unit_entity_links:insert('#', df.histfig_entity_link_memberst{entity_id = df.global.plotinfo.group_id, link_strength = 100})

        dfhack.gui.showAnnouncement(([[loyaltycascade: %s is now a member of %s again]]):format(unit_name, group_name), COLOR_WHITE)

        fixed = true
    end

    if fixed and unit.enemy.enemy_status_slot ~= -1 then
        local status_cache = unit.enemy.enemy_status_cache
        local status_slot = unit.enemy.enemy_status_slot

        unit.enemy.enemy_status_slot = -1
        status_cache.slot_used[status_slot] = false

        for _, value in pairs(status_cache.rel_map[status_slot]) do
            value = -1
        end

        for _, value in pairs(status_cache.rel_map) do
            value[status_slot] = -1
        end

        if cache.next_slot > status_slot then
            cache.next_slot = status_slot
        end
    end

    return false
end

local count = 0
for _, unit in pairs(df.global.world.units.all) do
    if dfhack.units.isCitizen(unit) and fixUnit(unit) then
        count = count + 1
    end
end

if count then
    print(([[Fixed %s units from a loyalty cascade.]]):format(count))
else
    print("No loyalty cascade found.")
end
