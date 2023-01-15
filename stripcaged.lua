local function plural(nr, name)
    -- '1 cage' / '4 cages'
    return string.format('%s %s%s', nr, name, nr ~= 1 and 's' or '')
end

local function cage_dump_items(list)
    local count = 0
    local count_cage = 0
    for _, cage in ipairs(list) do
        local pre_count = count
        for _, ref in ipairs(cage.general_refs) do
            if df.general_ref_contains_itemst:is_instance(ref) then
                local item = df.item.find(ref.item_id)
                if not item.flags.dump then
                    count = count + 1
                    item.flags.dump = true
                end
            end
        end
        if pre_count ~= count then count_cage = count_cage + 1 end
    end
    print(string.format('Dumped %s in %s', plural(count, 'item'),
        plural(count_cage, 'cage')))
end

local function cage_dump_armor(list)
    local count = 0
    local count_cage = 0
    for _, cage in ipairs(list) do
        local pre_count = count
        for _, ref in ipairs(cage.general_refs) do
            if df.general_ref_contains_unitst:is_instance(ref) then
                local inventory = df.unit.find(ref.unit_id).inventory
                for _, it in ipairs(inventory) do
                    if not it.item.flags.dump and
                        it.mode == df.unit_inventory_item.T_mode.Worn then
                        count = count + 1
                        it.item.flags.dump = true
                    end
                end
            end
        end
        if pre_count ~= count then count_cage = count_cage + 1 end
    end
    print(string.format('Dumped %s in %s', plural(count, 'armor piece'),
        plural(count_cage, 'cage')))
end

local function cage_dump_weapons(list)
    local count = 0
    local count_cage = 0
    for _, cage in ipairs(list) do
        local pre_count = count
        for _, ref in ipairs(cage.general_refs) do
            if df.general_ref_contains_unitst:is_instance(ref) then
                local inventory = df.unit.find(ref.unit_id).inventory
                for _, it in ipairs(inventory) do
                    if not it.item.flags.dump and
                        it.mode == df.unit_inventory_item.T_mode.Weapon then
                        count = count + 1
                        it.item.flags.dump = true
                    end
                end
            end
        end
        if pre_count ~= count then count_cage = count_cage + 1 end
    end
    print(string.format('Dumped %s in %s', plural(count, 'weapon'),
        plural(count_cage, 'cage')))
end

local function cage_dump_all(list)
    local count = 0
    local count_cage = 0

    for _, cage in ipairs(list) do
        local pre_count = count
        for _, ref in ipairs(cage.general_refs) do

            if df.general_ref_contains_itemst:is_instance(ref) then
                local item = df.item.find(ref.item_id)
                if not item.flags.dump then
                    count = count + 1
                    item.flags.dump = true
                end
            elseif df.general_ref_contains_unitst:is_instance(ref) then
                local inventory = df.unit.find(ref.unit_id).inventory
                for _, it in ipairs(inventory) do
                    if not it.item.flags.dump then
                        count = count + 1
                        it.item.flags.dump = true
                    end
                end
            end

        end
        if pre_count ~= count then count_cage = count_cage + 1 end
    end
    print(string.format('Dumped %s in %s', plural(count, 'item'),
        plural(count_cage, 'cage')))
end

local function cage_dump_list(list)
    local count_total = {}
    local empty_cages = 0
    for _, cage in ipairs(list) do
        local count = {}
        for _, ref in ipairs(cage.general_refs) do
            if df.general_ref_contains_itemst:is_instance(ref) then
                local classname = df.item_type.attrs[
                    df.item.find(ref.item_id):getType()].caption
                count[classname] = (count[classname] or 0) + 1
            elseif df.general_ref_contains_unitst:is_instance(ref) then
                local inventory = df.unit.find(ref.unit_id).inventory
                for _, it in ipairs(inventory) do
                    local classname = df.item_type.attrs[it.item:getType()].caption
                    count[classname] = (count[classname] or 0) + 1
                end
                -- TODO: vermin ?

                --[[ TODO: Determine how/if to handle a DEBUG flag.

                --Ruby:
                  else
                      puts "unhandled ref #{ref.inspect}" if $DEBUG
                  end
                ]]
            end
        end

        local type = df.item_type.attrs[cage:getType()].caption -- Default case
        if df.item_cagest:is_instance(cage) then
            type = 'Cage'
        elseif df.item_animaltrapst:is_instance(cage) then
            type = 'Animal trap'
        end

        -- If count is empty
        if not next(count) then
            empty_cages = empty_cages + 1
        else
            local sortedlist = {}
            for classname, n in pairs(count) do
                sortedlist[#sortedlist + 1] = {classname = classname, count = n}
            end
            table.sort(sortedlist, (function(i, j) return i.count < j.count end))
            print(('%s %d: '):format(type, cage.id))
            for _, t in ipairs(sortedlist) do
                print(' ' .. t.count .. ' ' .. t.classname)
            end
        end
        for k, v in pairs(count) do count_total[k] = (count_total[k] or 0) + v end
    end

    if #list > 1 then
        print('\nTotal:')
        local sortedlist = {}
        for classname, n in pairs(count_total) do
            sortedlist[#sortedlist + 1] = {classname = classname, count = n}
        end
        table.sort(sortedlist, (function(i, j) return i.count < j.count end))
        for _, t in ipairs(sortedlist) do
            print(' ' .. t.count .. ' ' .. t.classname)
        end
        print('with ' .. plural(empty_cages, 'empty cage'))
    end
end

-- handle magic script arguments

local args = {...}

local list
if args[2] == 'here' then
    print "NOTE: The 'here' option isn't well tested for v50 and only works with the keyboard cursor."
    local it = dfhack.gui.getSelectedItem(true)
    list = {it}
    if not df.item_cagest:is_instance(it) and
            not df.item_animaltrapst:is_instance(it) then
        list = {}
        for _, cage in ipairs(df.global.world.items.other.ANY_CAGE_OR_TRAP) do
            if same_xyz(df.global.cursor, cage.pos) then
                table.insert(list, cage)
            end
        end
    end
    if not list[1] then
        print 'Please select a cage'
        return
    end
elseif tonumber(args[2]) then -- Check if user provided ids
    list = {}
    for i = 2, #args do
        local id = args[i]
        local it = df.item.find(tonumber(id))
        if not it then
            print('Invalid item id ' .. id)
        elseif not df.item_cagest:is_instance(it) and
            not df.item_animaltrapst:is_instance(it) then
            print('Item ' .. id .. ' is not a cage')
        else
            list[#list + 1] = it
        end
    end
    if not list[1] then
        print 'Please use a valid cage id'
        return
    end
else
    list = df.global.world.items.other.ANY_CAGE_OR_TRAP
end

-- act
local choice = args[1]

if choice:match '^it' then
    cage_dump_items(list)
elseif choice:match '^arm' then
    cage_dump_armor(list)
elseif choice:match '^wea' then
    cage_dump_weapons(list)
elseif choice == 'all' then
    cage_dump_all(list)
elseif choice == 'list' then
    cage_dump_list(list)
else
    print(dfhack.script_help())
end
