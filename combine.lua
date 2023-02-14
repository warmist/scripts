-- Combines food and plant items across stockpiles. 
local argparse = require('argparse')
local utils = require('utils')

-- used when the info option is specified
local out_fp = nil
local out_name = ''
local out_err = nil

local opts, args = {
    help = false,
    preview = false,
    merge = false,
    stockpile = nil,
    types = nil,
    max = 0,
    info = false,
    debug = 0
  }, {...}

local valid_mode_list = {
    'preview',
    'merge'
}

local valid_modes = utils.invert(valid_mode_list)

local valid_types_list = {
    'all',
    'drink',
    'fat',
    'fish',
    'meal',
    'meat',
    'plant'
}

local valid_types = utils.invert(valid_types_list)

local valid_types_map = {
    ['all'] = { },
    ['drink'] = {[df.item_type.DRINK]={type_id=df.item_type.DRINK, type_name='DRINK',type_caste=false}},
    ['fat'] =   {[df.item_type.GLOB]={type_id=df.item_type.GLOB, type_name='GLOB',type_caste=false},
                [df.item_type.CHEESE]={type_id=df.item_type.CHEESE, type_name='CHEESE',type_caste=false}},
    ['fish'] = {[df.item_type.FISH]={type_id=df.item_type.FISH, type_name='FISH',type_caste=true},
                [df.item_type.FISH_RAW]={type_id=df.item_type.FISH_RAW, type_name='FISH_RAW',type_caste=true},
                [df.item_type.EGG]={type_id=df.item_type.EGG, type_name='EGG',type_caste=true}},
    ['meal'] = {[df.item_type.FOOD]={type_id=df.item_type.FOOD, type_name='FOOD',type_caste=false}},
    ['meat'] = {[df.item_type.MEAT]={type_id=df.item_type.MEAT, type_name='MEAT',type_caste=false}},
    ['plant'] = {[df.item_type.PLANT]={type_id=df.item_type.PLANT, type_name='PLANT',type_caste=false},
                [df.item_type.PLANT_GROWTH]={type_id=df.item_type.PLANT_GROWTH, type_name='PLANT_GROWTH',type_caste=false}}
}

-- populate all types
for k1,v1 in pairs(valid_types_map) do
    if k1 ~= 'all' then
        for k2,v2 in pairs(v1) do
            valid_types_map['all'][k2]={}
            for k3,v3 in pairs (v2) do
                valid_types_map['all'][k2][k3]=v3
            end
        end
    end
end

local function dbg(lvl, msg)
    if lvl <= opts.debug then
        dfhack.print(msg)
    end
end

local function info(msg)
    if out_fp then
        out_fp:write(msg)
        out_fp:flush()
    end
end

-- CList class
-- generic list class used for key value pairs.
local CList = { }

function CList:new(o)
    o = o or { }
    setmetatable(o, self)
    self.__index = self
    self.__len = function (t) local n = 0 for _, __ in pairs(t) do n = n + 1 end return n end
    return o
end

local function comp_item_new(comp_key)
    local comp_item = {}
    if not comp_key then qerror('new_comp_item: comp_key is nil') end
    comp_item.comp_key = comp_key
    comp_item.item_qty = 0
    comp_item.max_stack_size = opts.max or 0
    comp_item.before_stacks = 0
    comp_item.after_stacks = 0
    comp_item.before_stack_size = CList:new(nil)    -- key:item.id, val:item.stack_size
    comp_item.after_stack_size = CList:new(nil)     -- key:item.id, val:item.stack_size
    comp_item.items = CList:new(nil)                -- key:item.id, val:item
    comp_item.sorted_items = CList:new(nil)         -- key:-1*item.id | item.id, val:item_id
    return comp_item
end

local function comp_item_add_item(comp_item, item)
    if not comp_item.items[item.id] then

        comp_item.items[item.id] = item
        comp_item.item_qty = comp_item.item_qty + item.stack_size
        if item.stack_size >= comp_item.max_stack_size then
            comp_item.max_stack_size = item.stack_size
        end
        comp_item.before_stack_size[item.id] = item.stack_size
        comp_item.after_stack_size[item.id] = item.stack_size
        comp_item.before_stacks = comp_item.before_stacks + 1
        comp_item.after_stacks = comp_item.after_stacks + 1

        local contained_item = dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINED_IN_ITEM)

        -- used to merge contained items before loose items
        if contained_item then
            table.insert(comp_item.sorted_items, -1*item.id)
        else
            table.insert(comp_item.sorted_items, item.id)
        end
        return comp_item.items[item.id]
    else
        return nil
    end
end

local function stack_type_new(type_vals)
    local stack_type = {}
    for k,v in pairs(type_vals) do
        stack_type[k] = v
    end
    stack_type.item_qty = 0
    stack_type.before_stacks = 0
    stack_type.after_stacks = 0
    stack_type.max_stack_size = 0
    stack_type.comp_items = CList:new(nil)          -- key:comp_key, val=comp_item
    return stack_type
end

local function stacks_type_add_item(stacks_type, item)
    local comp_key = ''

    if stacks_type.type_caste then
        comp_key = tostring(stacks_type.type_id) .. tostring(item.race) .. tostring(item.caste)
    else
        comp_key = tostring(stacks_type.type_id) .. tostring(item.mat_type) .. tostring(item.mat_index)
    end

    if not stacks_type.comp_items[comp_key] then
        stacks_type.comp_items[comp_key] = comp_item_new(comp_key)
    end

    if comp_item_add_item(stacks_type.comp_items[comp_key], item) then
        stacks_type.before_stacks = stacks_type.before_stacks + 1
        stacks_type.after_stacks = stacks_type.after_stacks + 1
        stacks_type.item_qty = stacks_type.item_qty + item.stack_size
        if stacks_type.comp_items[comp_key].max_stack_size > stacks_type.max_stack_size then
            stacks_type.max_stack_size = stacks_type.comp_items[comp_key].max_stack_size
        end
    else
        dbg(1, ('stacks_type_add_item: item id %d twice to stack: ignored'):format(item.id))
    end
end

local function print_stacks_info(stacks)
    -- print stacks details to the file
    info(('Details #types:%5d\n'):format(#stacks))
    for _, stacks_type in pairs(stacks) do
        info(('   type: <%12s> <%d>  comp item types#:%5d  #item_qty:%5d  stack sizes: max: %5d before:%5d after:%5d\n'):format(stacks_type.type_name, stacks_type.type_id,  stacks_type.item_qty, #stacks_type.comp_items, stacks_type.max_stack_size, stacks_type.before_stacks, stacks_type.after_stacks))
        for _, comp_item in pairs(stacks_type.comp_items) do
            info(('      compare key:%12s  #item qty:%5d  #comp item stacks:%5d  stack sizes: max: %5d before:%5d after:%5d\n'):format(comp_item.comp_key, comp_item.item_qty, #comp_item.items, comp_item.max_stack_size, comp_item.before_stacks, comp_item.after_stacks))
            for _, item in pairs(comp_item.items) do
                info(('         item:%40s <%6d> before:%5d after:%5d\n'):format(utils.getItemDescription(item), item.id, comp_item.before_stack_size[item.id], comp_item.after_stack_size[item.id]))
            end
        end
    end
end

local function print_stacks_summary(stacks)
    -- print stacks summary to the console
    dfhack.print(('Summary:\n'))
    for _, stacks_type in pairs(stacks) do
        dfhack.print(('   type: <%12s> <%d>   #item_qty:%5d  stack sizes:  max: %5d  before:%5d  after:%5d\n'):format(stacks_type.type_name, stacks_type.type_id,  stacks_type.item_qty, stacks_type.max_stack_size, stacks_type.before_stacks, stacks_type.after_stacks))
    end
end

local function b2d(b)
    if b then return 1 else return 0 end
end

local function isRestrictedItem(item)
    -- is the item restricted from merging?
    local flags = item.flags
    dbg(5, (' item.id %6d flags: %d%d%d%d%d%d%d%d%d%d%d%d'):format(item.id, b2d(flags.rotten), b2d(flags.trader),
        b2d(flags.hostile), b2d(flags.forbid), b2d(flags.dump), b2d(flags.on_fire),
        b2d(flags.garbage_collect), b2d(flags.owned), b2d(flags.removed), b2d(flags.encased),
        b2d(flags.spider_web), b2d(#item.specific_refs > 0)), 1)

    return flags.rotten or flags.trader or flags.hostile or flags.forbid
        or flags.dump or flags.on_fire or flags.garbage_collect or flags.owned
        or flags.removed or flags.encased or flags.spider_web or #item.specific_refs > 0
end


function stacks_add_items(stacks, items, ind)
-- loop through each item and add it to the matching stack types list
-- recursively calls itself to add contained items
    if not ind then ind = '' end

    for _, item in pairs(items) do
        local type_id = item:getType()
        local stacks_type = stacks[type_id]

        -- item type in list of included types?
        if stacks_type then
            if not isRestrictedItem(item) then

                stacks_type_add_item(stacks_type, item)

                info(('      %sitem:%40s <%6d> is incl, type %d\n'):format(ind, utils.getItemDescription(item), item.id, type_id))
            else
                -- restricted
                info(('      %sitem:%40s <%6d> is restricted\n'):format(ind, utils.getItemDescription(item), item.id))
            end

        -- add contained items
        elseif dfhack.items.getGeneralRef(item, df.general_ref_type.CONTAINS_ITEM) then
            local contained_items = dfhack.items.getContainedItems(item)
            info(('      %sContainer:%s <%6d> #items:%5d\n'):format(ind, utils.getItemDescription(item), item.id, #contained_items))
            stacks_add_items(stacks, contained_items, ind .. '   ')

        -- excluded item types
        else
            info(('      %sitem:%40s <%6d> is excl, type %d\n'):format(ind, utils.getItemDescription(item), item.id, type_id))
        end
    end
end

local function populate_stacks(stacks, stockpiles, types)
    -- loop through each stockpile and add items
    info(('Populating phase\n'))
    info(('stack types\n'))
    for type_id, type_vals in pairs(types) do
        if not stacks[type_id] then
            stacks[type_id] = stack_type_new(type_vals)
            local stacks_type = stacks[type_id]
            info(('   type: <%12s> <%d>   #item_qty:%5d  stack sizes:  max: %5d  before:%5d  after:%5d\n'):format(stacks_type.type_name, stacks_type.type_id,  stacks_type.item_qty, stacks_type.max_stack_size, stacks_type.before_stacks, stacks_type.after_stacks))
        end
    end

    -- iterate across items in the stockpile and populate the food types structure
    info(('stockpiles\n'))
    for _, stockpile in pairs(stockpiles) do

        local items = dfhack.buildings.getStockpileContents(stockpile)
        info(('   stockpile:%30s <%6d> pos:(%3d,%3d,%3d) #items:%5d\n'):format(stockpile.name, stockpile.id, stockpile.centerx, stockpile.centery, stockpile.z,  #items))

        if #items > 0 then
            stacks_add_items(stacks, items)
        else
            info('      skipping stockpile: no items\n')
        end
    end
end
    
local function preview_stacks(stacks)
    -- calculate the stacks sizes and store in after_stack_size
    info('\nPreview phase\n')
    for _, stacks_type in pairs(stacks) do
        for comp_key, comp_item in pairs(stacks_type.comp_items) do
            -- sort the items.
            table.sort(comp_item.sorted_items)

            -- actual max stacksize is total quantity of items divided by number of current stacks
            local max_stack_size = math.floor(comp_item.item_qty / #comp_item.items)

            -- use higher of provided max stacksize and actual max stacksize
            -- in case provided max is a lower stack size than can be used to distribute the total item qty
            max_stack_size = math.max(comp_item.max_stack_size, opts.max)

            -- how many stacks are needed ?
            local max_stacks_needed = math.floor(comp_item.item_qty / max_stack_size)

            -- how many items are left over after the max stacks are allocated?
            local stack_remainder = comp_item.item_qty - max_stacks_needed * max_stack_size

            -- update the after stack sizes. use the sorted items list to get the items.
            for _, s_item in ipairs(comp_item.sorted_items) do
                local item_id = s_item
                if s_item < 0 then item_id = s_item * -1 end
                local item = comp_item.items[item_id]
                if max_stacks_needed > 0 then
                    max_stacks_needed = max_stacks_needed - 1
                    comp_item.after_stack_size[item.id] = max_stack_size
                elseif stack_remainder > 0 then
                    comp_item.after_stack_size[item.id] = stack_remainder
                    stack_remainder = 0
                elseif stack_remainder == 0 then
                    comp_item.after_stack_size[item.id] = stack_remainder
                    comp_item.after_stacks = comp_item.after_stacks - 1
                    stacks_type.after_stacks = stacks_type.after_stacks - 1
                end
            end
        end
    end
end

local function merge_stacks(stacks)
    -- apply the stack size changes in the after_stack_size
    info('Merge phase\n')
    for _, stacks_type in pairs(stacks) do
        for comp_key, comp_item in pairs(stacks_type.comp_items) do
            for _, item in pairs(comp_item.items) do
                if comp_item.after_stack_size[item.id] == 0 then
                    local remove_item = df.item.find(item.id)
                    dfhack.items.remove(remove_item)
                elseif item.stack_size ~= comp_item.after_stack_size[item.id] then
                    item.stack_size = comp_item.after_stack_size[item.id]
                end
            end
        end
    end
end

local function parse_preview_opts(opts, arg)
    if opts.merge and opts.preview then
        qerror('Expected: only one of preview, merge')
    end
    dfhack.print('Mode: preview\n')
    return true
end

local function parse_merge_opts(opts, arg)
    if opts.merge and opts.preview then
        qerror('Expected: only one of preview, merge')
    end
    dfhack.print('Mode: merge\n')
    return true
end

local function parse_stockpile_opts(opts, arg)

    local stockpiles = {}

    if arg == 'all' then
        for _, building in pairs(df.global.world.buildings.all) do
            if building:getType() == df.building_type.Stockpile then
                table.insert(stockpiles, building)
            end
        end
        dfhack.print(('Stockpile(all): %d found\n'):format(#stockpiles))
    elseif arg == 'here' then
        local pos = argparse.coords(arg, 'stockpile')
        local building = dfhack.buildings.findAtTile(pos)
        if not building or building:getType() ~= df.building_type.Stockpile then qerror('Stockpile not found at game cursor position.') end
        table.insert(stockpiles, building)
        local items = dfhack.buildings.getStockpileContents(building)
        dfhack.print(('Stockpile(here): %s <%d> pos:(%d, %d, %d) #items:%d\n'):format(building.name, building.id, building.centerx, building.centery, building.z, #items))

    else -- stockpile=id?
        local stockpile_id = argparse.positiveInt(arg, 'stockpile')
        local building = df.building.find(stockpile_id)
        if not building then
            qerror(('Stockpile id %d not found.'):format(stockpile_id))
        elseif building:getType() ~= df.building_type.Stockpile then
            qerror(('Building id %d not a stockpile.'):format(stockpile_id))
        end
        table.insert(stockpiles, building)
        local items = dfhack.buildings.getStockpileContents(building)
        dfhack.print(('Stockpile(id): %s <%d> pos:(%d, %d, %d) #items:%d\n'):format(building.name, building.id, building.centerx, building.centery, building.z, #items))
    end
    return stockpiles
end


local function parse_types_opts(opts, arg)
    local types = {}
    local div = ''

    if not arg then
        qerror('Expected: comma separated list of types')
    end

    dfhack.print('Types: ')

    for _, t in pairs(argparse.stringList(arg)) do
        if not valid_types[t] then
            qerror(('Unknown type: %d'):format(arg))
        end

        for k2, v2 in pairs(valid_types_map[t]) do
            if not types[k2] then
                types[k2]={}
                for k3, v3 in pairs(v2) do
                    types[k2][k3]=v3
                end
                dfhack.print(div .. types[k2].type_name)
                div=', '
            end
        end
    end
    dfhack.print('\n')

    return types
end

local function parse_info_opts(opts, arg)
    -- open a file for detailed information, to avoid cluttering the console.
    out_name = arg
    if not out_name or out_name == '' then qerror('Expected: filename') end
    out_fp, out_err = io.open(out_name, 'w')
    if not out_fp then qerror('File open error: ' .. out_err) end
    dfhack.print(('Info: writing to filename: %s\n'):format(out_name))
end

local function parse_commandline(opts, args)

    if args[1] == 'help' or not args[1] then
        opts.help = true
        return
    end

    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() opts.help = true end},
            {'p', 'preview', handler=function(optarg) opts.preview=parse_preview_opts(opts, optarg) end},
            {'m', 'merge', handler=function(optarg) opts.merge=parse_merge_opts(opts, optarg) end},
            {'s', 'stockpile', hasArg=true, handler=function(optarg) opts.stockpile=parse_stockpile_opts(opts, optarg) end},
            {'t', 'types', hasArg=true, handler=function(optarg) opts.types=parse_types_opts(opts, optarg) end},
            {'x', 'max', hasArg=true, handler=function(optarg) opts.max = argparse.positiveInt(optarg, 'max') end},
            {'i', 'info', hasArg=true, handler=function(optarg) opts.info = parse_info_opts(opts, optarg) end},
            {'d', 'debug', hasArg=true, handler=function(optarg) opts.debug = argparse.positiveInt(optarg, 'debug') print('Debug info [ON]') end},
    })

    -- if mode is not specified, then default to preview
    if not opts.preview and not opts.mode then
        opts.preview = true
    end

    -- if a cursor and stockpile are not specificed, then default to all stockpiles
    if not opts.cursor and not opts.stockpile then
        opts.stockpile=parse_stockpile_opts(opts, 'all')
    end

    -- if a type is not specified, then default to all types
    if not opts.types then
        opts.types = valid_types_map['all']
    end

    if opts.max > 0 then
        dfhack.print(('Maximum stack size: %d\n'):format(opts.max))
    end

end


-- main program starts here
local function main()

    if df.global.gamemode ~= df.game_mode.DWARF or not dfhack.isMapLoaded() then
        qerror('combine needs a loaded fortress map to work\n')
    end

    parse_commandline(opts, args)

    if opts.help then
        print(dfhack.script_help())
        return
    end

    local stacks = CList:new()

    populate_stacks(stacks,  opts.all or opts.cursor or opts.stockpile, opts.types)

    preview_stacks(stacks)

    if opts.merge then
        merge_stacks(stacks)
    end

    print_stacks_info(stacks)
    print_stacks_summary(stacks)

    if out_fp then
        io.close(out_fp)
    end
end

if not dfhack_flags.module then
    main()
end
