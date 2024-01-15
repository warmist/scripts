--@module = true
-----------------------------------------------------------
-- helper functions
-----------------------------------------------------------

-- check whether an item is inside a burrow
local function containsItem(burrow,item)
    local res = false
    local x,y,z = dfhack.items.getPosition(item)
    if x then
        res = dfhack.burrows.isAssignedTile(burrow, xyz2pos(x,y,z))
    end
    return res
end

-- fast reachability test for items that requires precomputed walkability groups for
-- all citizens. Returns false for items w/o valid position (e.g., items in inventories).
--- @param item item
--- @param wgroups table<integer,boolean>
--- @return boolean
function fastReachable(item,wgroups)
    local x, y, z = dfhack.items.getPosition(item)
    if x then -- item has a valid position
        local igroup = dfhack.maps.getWalkableGroup(xyz2pos(x, y, z))
        return not not wgroups[igroup]
    else
        return false
    end
end

--- @return table<integer,boolean>
function citizenWalkabilityGroups()
    local cgroups = {}
    for _, unit in pairs(dfhack.units.getCitizens(true)) do
        local wgroup = dfhack.maps.getWalkableGroup(unit.pos)
        cgroups[wgroup] = true
    end
    cgroups[0] = false -- exclude unwalkable tiles
    return cgroups
end

-----------------------------------------------------------------------
-- external API: helpers to assemble filters and `execute` to execute.
-----------------------------------------------------------------------

--- @alias conditions (fun(item:item):boolean)[]

--- @param tab conditions
--- @param burrow burrow
--- @param outside boolean
function condition_burrow(tab,burrow, outside)
    if outside then
        table.insert(tab, function (item) return not containsItem(burrow, item) end)
    else
        table.insert(tab, function (item) return containsItem(burrow, item) end)
    end
end

--- @param tab conditions
--- @param match number|string
function condition_type(tab, match)
    if type(match) == "string" then
        table.insert(
            tab,
            function (item) return df.item_type[item:getType()] == string.upper(match) end
        )
    elseif type(match) == "number" then
        table.insert(
            tab,
            function (item) return item:getType() == type end
        )
    else error("match argument must be string or number")
    end
end

--- @param tab conditions
function condition_reachable(tab)
    local cgroups = citizenWalkabilityGroups()
    table.insert(tab, function(item) return fastReachable(item, cgroups) end)
end

--- @param tab conditions
function condition_unreachable(tab)
    local cgroups = citizenWalkabilityGroups()
    table.insert(tab, function (item) return not fastReachable(item,cgroups) end)
end

-- uses the singular form without stack size (i.e., prickle berry)
--- @param tab conditions
--- @param desc string # Lua pattern: https://www.lua.org/manual/5.4/manual.html#6.4.1
function condition_description(tab, pattern)
    table.insert(
        tab,
        function(item)
            -- remove trailing stack size for corpse pieces like "wool" (work around DF bug)
            local desc = dfhack.items.getDescription(item, 1):gsub(' %[%d+%]','')
            return not not desc:find(pattern)
        end
    )
end

--- @param tab conditions
--- @param material string
function condition_material(tab, material)
    table.insert(
        tab,
        function(item) return dfhack.matinfo.decode(item):toString() == material end)
end

--- @param tab conditions
--- @param match string
function condition_matcat(tab, match)
    if df.dfhack_material_category[match] ~= nil then
        table.insert(
            tab,
            function (item)
                local matinfo = dfhack.matinfo.decode(item)
                return matinfo:matches{[match]=true}
            end
        )
    else
        qerror("invalid material category")
    end
end

--- @param tab conditions
--- @param lower number # range: 0 (pristine) to 3 (XX)
--- @param upper number # range: 0 (pristine) to 3 (XX)
function condition_wear(tab, lower, upper)
    table.insert(tab,
                 function(item) return lower <= item.wear and item.wear <= upper end)
end

--- @param tab conditions
--- @param lower number # range: 0 (standard) to 5 (masterwork)
--- @param upper number # range: 0 (standard) to 5 (masterwork)
function condition_quality(tab, lower, upper)
    table.insert(tab,
                 function(item) return lower <= item.quality and item.quality <= upper end)
end

--- @param tab conditions
function condition_forbidden(tab)
    table.insert(tab, function(item) return item.flags.forbid end)
end

--- @param tab conditions
function condition_melt(tab)
    table.insert(tab,function (item) return item.flags.melt end)
end

--- @param tab conditions
function condition_dump(tab)
    table.insert(tab, function(item) return item.flags.dump end)
end

--- @param tab conditions
function condition_hidden(tab)
    table.insert(tab, function(item) return item.flags.hidden end)
end

function condition_visible(tab)
    table.insert(tab, function(item) return not item.flags.hidden end)
end



--- @param action "melt"|"unmelt"|"forbid"|"unforbid"|"dump"|"undump"|"count"|"hide"|"unhide"
--- @param conditions conditions
--- @param options { help : boolean, artifact : boolean, dryrun : boolean, by_type : boolean }
--- @return number, table<number,number>
function execute(action, conditions, options)
    local count = 0
    local types = {}

    for _, item in pairs(df.global.world.items.other.IN_PLAY) do
        -- never act on items used for constructions/building materials and carried by hostiles
        -- also skip artifacts, unless explicitly told to include them
        if item.flags.construction or
            item.flags.in_building or
            item.flags.hostile or
            (item.flags.artifact and not options.artifact)
        then
            goto skipitem
        end

        -- implicit filters:
        if action == 'melt' and (item.flags.melt or not dfhack.items.canMelt(item)) or
            action == 'unmelt' and not item.flags.melt or
            action == 'forbid' and item.flags.forbid or
            action == 'unforbid' and not item.flags.forbid or
            action == 'dump' and (item.flags.dump or item.flags.artifact) or
            action == 'undump' and not item.flags.dump or
            action == 'hide' and item.flags.hidden or
            action == 'unhide' and not item.flags.hidden
        then
            goto skipitem
        end

        -- check conditions provided via options
        for _, condition in pairs(conditions) do
            if not condition(item) then goto skipitem end
        end

        -- skip items that are in unrevealed parts of the map
        local x, y, z = dfhack.items.getPosition(item)
        if x and not dfhack.maps.isTileVisible(x, y, z) then
            goto skipitem
        end

        -- item matches the filters
        count = count + 1
        if options.by_type then
            local it = item:getType()
            types[it] = (types[it] or 0) + 1
        end

        -- carry out the action
        if action == 'forbid' and not options.dryrun then
            item.flags.forbid = true
        elseif action == 'unforbid' and not options.dryrun then
            item.flags.forbid = false
        elseif action == 'dump' and not options.dryrun then
            item.flags.dump = true
        elseif action == 'undump' and not options.dryrun then
            item.flags.dump = false
        elseif action == 'melt' and not options.dryrun then
            dfhack.items.markForMelting(item)
        elseif action == 'unmelt' and not options.dryrun then
            dfhack.items.cancelMelting(item)
        elseif action == "hide" and not options.dryrun then
            item.flags.hidden = true
        elseif action == "unhide" and not options.dryrun then
            item.flags.hidden = false
        end
        :: skipitem ::
    end

    return count, types
end

--- @param action "melt"|"unmelt"|"forbid"|"unforbid"|"dump"|"undump"|"count"|"hide"|"unhide"
--- @param conditions conditions
--- @param options { help : boolean, artifact : boolean, dryrun : boolean, by_type : boolean }
function executeWithPrinting (action, conditions, options)
    local count, types = execute(action, conditions, options)
    print(count, 'items matched the filter options')
    if options.by_type and count > 0 then
        local sorted = {}
        for tp, ct in pairs(types) do
            table.insert(sorted, { type = tp, count = ct })
        end
        table.sort(sorted, function(a, b) return a.count > b.count end)
        print(("\n%-14s %5s\n"):format("TYPE", "COUNT"))
        for _, t in pairs(sorted) do
            print(("%-14s %5s"):format(df.item_type[t.type], t.count))
        end
        print()
    end
    if action == "count" or options.dryrun then
        print('no items were modified')
    end
end

-----------------------------------------------------------------------
-- script action: check for arguments and main action and run act
-----------------------------------------------------------------------

if dfhack_flags.module then
    return
end

local argparse = require('argparse')

local options = {
    help = false,
    artifact = false,
    dryrun = false,
    by_type = false,
}

--- @type (fun(item:item):boolean)[]
local conditions = {}

local positionals = argparse.processArgsGetopt({ ... }, {
  { 'h', 'help', handler = function() options.help = true end },
  { 'a', 'include-artifacts', handler = function() options.artifact = true end },
  { 'n', 'dry-run', handler = function() options.dryrun = true end },
  { nil, 'by-type', handler = function() options.by_type = true end },
  { 'i', 'inside', hasArg = true,
    handler = function (name)
        local burrow = dfhack.burrows.findByName(name,true)
        if burrow then condition_burrow(conditions, burrow, false)
        else qerror('burrow '..name..' not found') end
    end
  },
  { 'o', 'outside', hasArg = true,
    handler = function (name)
        local burrow = dfhack.burrows.findByName(name,true)
        if burrow then condition_burrow(conditions, burrow, true)
        else qerror('burrow '..name..' not found') end
    end
  },
  { 'r', 'reachable',
    handler = function () condition_reachable(conditions) end },
  { 'u', 'unreachable',
    handler = function () condition_unreachable(conditions) end },
  { 't', 'type', hasArg = true,
    handler = function (type) condition_type(conditions,type) end },
  { 'd', 'description', hasArg = true,
    handler = function (desc) condition_description(conditions, desc) end },
  { 'm', 'material', hasArg = true,
    handler = function (material) condition_material(conditions, material) end },
  { 'c', 'mat-category', hasArg = true,
    handler = function (matcat) condition_matcat(conditions, matcat) end },
  { 'w', 'min-wear', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'min-wear')
        condition_wear(conditions, level , 3) end },
  { 'W', 'max-wear', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'max-wear')
        condition_wear(conditions, 0, level) end },
  { 'q', 'min-quality', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'min-quality')
        condition_quality(conditions, level, 5) end },
  { 'Q', 'max-quality', hasArg = true,
    handler = function(levelst)
        local level = argparse.nonnegativeInt(levelst, 'max-quality')
        condition_quality(conditions, 0, level) end },
  { nil, 'forbidden',
    handler = function () condition_forbidden(conditions) end },
  { nil, 'melting',
    handler = function () condition_melt(conditions) end },
  { nil, 'dumping',
    handler = function () condition_dump(conditions) end },
  { nil, 'hidden',
    handler = function () condition_hidden(conditions) end },
  { nil, 'visible',
    handler = function () condition_visible(conditions) end }
})

if options.help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
elseif positionals[1] == 'forbid'   then executeWithPrinting('forbid',conditions,options)
elseif positionals[1] == 'unforbid' then executeWithPrinting('unforbid',conditions,options)
elseif positionals[1] == 'dump'     then executeWithPrinting('dump',conditions,options)
elseif positionals[1] == 'undump'   then executeWithPrinting('undump',conditions,options)
elseif positionals[1] == 'melt'     then executeWithPrinting('melt',conditions,options)
elseif positionals[1] == 'unmelt'   then executeWithPrinting('unmelt',conditions,options)
elseif positionals[1] == 'count'    then executeWithPrinting('count',conditions,options)
elseif positionals[1] == 'hide'     then executeWithPrinting('hide',conditions,options)
elseif positionals[1] == 'unhide'   then executeWithPrinting('unhide',conditions,options)
else qerror('main action not recognized')
end
