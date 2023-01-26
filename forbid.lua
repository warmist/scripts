-- Forbid and list forbidden items on the map.

local argparse = require('argparse')

local function isItemReachable(item)
    local block = dfhack.maps.getTileBlock(item.pos)

    return block and block.walkable[item.pos.x % 16][item.pos.y % 16] ~= 0
end

local function getForbiddenItems()
    local items = {}

    for _, item in pairs(df.global.world.items.all) do
        if item.flags.forbid then
            local item_type = df.item_type[item:getType()]

            items[item_type] = (items[item_type] or 0) + 1
        end
    end

    return items
end

local options, args = {
    help = false,
}, { ... }

local positionals = argparse.processArgsGetopt(args, {
    { 'h', 'help', handler = function() options.help = true end }
})

if positionals[1] == "help" or options.help then
    print(dfhack.script_help())
end

if positionals[1] == "list" then
    local forbidden_items = getForbiddenItems()
    local sorted_items = {}

    for item_type, count in pairs(forbidden_items) do
        table.insert(sorted_items, { type = item_type, count = count })
    end

    table.sort(sorted_items, function(a, b)
        return a.count > b.count
    end)

    if #sorted_items == 0 then
        print("No forbidden items found on the map.")
    else
        print("Forbidden items on the map by type:\n")
        print(("%-14s %5s\n"):format("TYPE", "COUNT"))

        for _, item in pairs(sorted_items) do
            print(("%-14s %5s"):format(item.type, item.count))
        end
    end
end

if positionals[1] == "all" then
    print("Forbidding all items on the map...")

    local count = 0
    for _, item in pairs(df.global.world.items.all) do
        item.flags.forbid = true
        count = count + 1
    end

    print(("Forbade %s items, you can unforbid them by running `unforbid all`"):format(count))
end

if positionals[1] == "unreachable" then
    print("Forbidding all unreachable items on the map...")

    local count = 0
    for _, item in pairs(df.global.world.items.all) do
        if item.flags.on_ground and not isItemReachable(item) then
            item.flags.forbid = true
            count = count + 1
        end
    end

    print(("Forbade %s items, you can unforbid them by running `unforbid all`"):format(count))
end
