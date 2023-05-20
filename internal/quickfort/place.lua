-- place-related data and logic for the quickfort script
--@ module = true
--[[
stockpiles data structure:
  list of {type, cells, pos, width, height, extent_grid}
- type: letter from stockpile designation screen
- cells: list of source spreadsheet cell labels (for debugging)
- pos: target map coordinates of upper left corner of extent (or nil if invalid)
- width, height: number between 1 and 31 (could be 0 if pos == nil)
- extent_grid: [x][y] -> boolean where 1 <= x <= width and 1 <= y <= height
]]

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

require('dfhack.buildings') -- loads additional functions into dfhack.buildings
local utils = require('utils')
local stockpiles = require('plugins.stockpiles')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_building = reqscript('internal/quickfort/building')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_set = reqscript('internal/quickfort/set')

local log = quickfort_common.log

local function is_valid_stockpile_tile(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    if flags.hidden or occupancy.building ~= 0 then return false end
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES or
            shape == df.tiletype_shape.STAIR_UP or
            shape == df.tiletype_shape.STAIR_DOWN or
            shape == df.tiletype_shape.STAIR_UPDOWN or
            shape == df.tiletype_shape.RAMP or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
end

local function is_valid_stockpile_extent(s)
    for extent_x, col in ipairs(s.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then return true end
        end
    end
    return false
end

local stockpile_template = {
    has_extents=true, min_width=1, max_width=31, min_height=1, max_height=31,
    is_valid_tile_fn = is_valid_stockpile_tile,
    is_valid_extent_fn = is_valid_stockpile_extent
}

local stockpile_db = {
    a={label='Animal', categories={'animals'}},
    f={label='Food', categories={'food'}, want_barrels=true},
    u={label='Furniture', categories={'furniture'}},
    n={label='Coins', categories={'coins'}, want_bins=true},
    y={label='Corpses', categories={'corpses'}},
    r={label='Refuse', categories={'refuse'}},
    s={label='Stone', categories={'stone'}, want_wheelbarrows=true},
    w={label='Wood', categories={'wood'}},
    e={label='Gem', categories={'gems'}, want_bins=true},
    b={label='Bar/Block', categories={'bars_blocks'}, want_bins=true},
    h={label='Cloth', categories={'cloth'}, want_bins=true},
    l={label='Leather', categories={'leather'}, want_bins=true},
    z={label='Ammo', categories={'ammo'}, want_bins=true},
    S={label='Sheets', categories={'sheets'}, want_bins=true},
    g={label='Finished Goods', categories={'finished_goods'}, want_bins=true},
    p={label='Weapons', categories={'weapons'}, want_bins=true},
    d={label='Armor', categories={'armor'}, want_bins=true},
    c={label='Custom', categories={}}
}
for _, v in pairs(stockpile_db) do utils.assign(v, stockpile_template) end

local function add_resource_digit(cur_val, digit)
    return (cur_val * 10) + digit
end

local function custom_stockpile(_, keys)
    local labels, categories = {}, {}
    local want_bins, want_barrels, want_wheelbarrows = false, false, false
    local num_bins, num_barrels, num_wheelbarrows = nil, nil, nil
    local prev_key, in_digits = nil, false
    for k in keys:gmatch('.') do
        local digit = tonumber(k)
        if digit and prev_key then
            local db_entry = rawget(stockpile_db, prev_key)
            if db_entry.want_bins then
                if not in_digits then num_bins = 0 end
                num_bins = add_resource_digit(num_bins, digit)
            elseif db_entry.want_barrels then
                if not in_digits then num_barrels = 0 end
                num_barrels = add_resource_digit(num_barrels, digit)
            else
                if not in_digits then num_wheelbarrows = 0 end
                num_wheelbarrows = add_resource_digit(num_wheelbarrows, digit)
            end
            in_digits = true
            goto continue
        end
        if not rawget(stockpile_db, k) then return nil end
        table.insert(labels, stockpile_db[k].label)
        table.insert(categories, stockpile_db[k].categories[1])
        want_bins = want_bins or stockpile_db[k].want_bins
        want_barrels = want_barrels or stockpile_db[k].want_barrels
        want_wheelbarrows =
                want_wheelbarrows or stockpile_db[k].want_wheelbarrows
        prev_key = k
        -- flag that we're starting a new (potential) digit sequence and we
        -- should reset the accounting for the relevent resource number
        in_digits = false
        ::continue::
    end
    local stockpile_data = {
        label=table.concat(labels, '+'),
        categories=categories,
        want_bins=want_bins,
        want_barrels=want_barrels,
        want_wheelbarrows=want_wheelbarrows,
        num_bins=num_bins,
        num_barrels=num_barrels,
        num_wheelbarrows=num_wheelbarrows
    }
    utils.assign(stockpile_data, stockpile_template)
    return stockpile_data
end

setmetatable(stockpile_db, {__index=custom_stockpile})

local function configure_stockpile(bld, db_entry)
    for _,cat in ipairs(db_entry.categories) do
        local name = ('library/cat_%s'):format(cat)
        stockpiles.import_stockpile(name, {id=bld.id, mode='enable', filters={}})
    end
end

local function init_containers(db_entry, ntiles, fields)
    if db_entry.want_barrels then
        local max_barrels = db_entry.num_barrels or
                quickfort_set.get_setting('stockpiles_max_barrels')
        if max_barrels < 0 or max_barrels >= ntiles then
            fields.max_barrels = ntiles
        else
            fields.max_barrels = max_barrels
        end
        log('barrels set to %d', fields.max_barrels)
    end
    if db_entry.want_bins then
        local max_bins = db_entry.num_bins or
                quickfort_set.get_setting('stockpiles_max_bins')
        if max_bins < 0 or max_bins >= ntiles then
            fields.max_bins = ntiles
        else
            fields.max_bins = max_bins
        end
        log('bins set to %d', fields.max_bins)
    end
    if db_entry.want_wheelbarrows or db_entry.num_wheelbarrows then
        local max_wb = db_entry.num_wheelbarrows or
                quickfort_set.get_setting('stockpiles_max_wheelbarrows')
        if max_wb < 0 then max_wb = 1 end
        if max_wb >= ntiles - 1 then
            fields.max_wheelbarrows = ntiles - 1
        else
            fields.max_wheelbarrows = max_wb
        end
        log('wheelbarrows set to %d', fields.max_wheelbarrows)
    end
end

local function create_stockpile(s, dry_run)
    local db_entry = stockpile_db[s.type]
    log('creating %s stockpile at map coordinates (%d, %d, %d), defined from' ..
        ' spreadsheet cells: %s',
        db_entry.label, s.pos.x, s.pos.y, s.pos.z, table.concat(s.cells, ', '))
    local extents, ntiles = quickfort_building.make_extents(s, dry_run)
    local fields = {room={x=s.pos.x, y=s.pos.y, width=s.width, height=s.height,
                          extents=extents}}
    init_containers(db_entry, ntiles, fields)
    if dry_run then return ntiles end
    local bld, err = dfhack.buildings.constructBuilding{
        type=df.building_type.Stockpile, abstract=true, pos=s.pos,
        width=s.width, height=s.height, fields=fields}
    if not bld then
        -- this is an error instead of a qerror since our validity checking
        -- is supposed to prevent this from ever happening
        error(string.format('unable to place stockpile: %s', err))
    end
    configure_stockpile(bld, db_entry)
    return ntiles
end

function do_run(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.place_designated = stats.place_designated or
            {label='Stockpiles designated', value=0, always=true}
    stats.place_tiles = stats.place_tiles or
            {label='Stockpile tiles designated', value=0}
    stats.place_occupied = stats.place_occupied or
            {label='Stockpile tiles skipped (tile occupied)', value=0}

    local stockpiles = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, stockpiles, stockpile_db)
    stats.out_of_bounds.value =
            stats.out_of_bounds.value + quickfort_building.crop_to_bounds(
                ctx, stockpiles, stockpile_db)
    stats.place_occupied.value =
            stats.place_occupied.value +
            quickfort_building.check_tiles_and_extents(
                ctx, stockpiles, stockpile_db)

    local dry_run = ctx.dry_run
    for _, s in ipairs(stockpiles) do
        if s.pos then
            local ntiles = create_stockpile(s, dry_run)
            stats.place_tiles.value = stats.place_tiles.value + ntiles
            stats.place_designated.value = stats.place_designated.value + 1
        end
    end
    if dry_run then return end
    dfhack.job.checkBuildingsNow()
end

-- enqueues orders only for explicitly requested containers
function do_orders(zlevel, grid, ctx)
    local stockpiles = {}
    quickfort_building.init_buildings(
        ctx, zlevel, grid, stockpiles, stockpile_db)
    for _, s in ipairs(stockpiles) do
        local db_entry = stockpile_db[s.type]
        quickfort_orders.enqueue_container_orders(ctx,
            db_entry.num_bins, db_entry.num_barrels, db_entry.num_wheelbarrows)
    end
end

function do_undo(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.place_removed = stats.place_removed or
            {label='Stockpiles removed', value=0, always=true}

    local stockpiles = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, stockpiles, stockpile_db)

    for _, s in ipairs(stockpiles) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and bld:getType() == df.building_type.Stockpile then
                    if not ctx.dry_run then
                        dfhack.buildings.deconstruct(bld)
                    end
                    stats.place_removed.value = stats.place_removed.value + 1
                end
                ::continue::
            end
        end
    end
end
