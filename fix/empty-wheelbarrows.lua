--checks all wheelbarrows on map for rocks stuck in them. If a wheelbarrow isn't in use for a job (hauling) then there should be no rocks in them
--rocks will occasionally get stuck in wheelbarrows, and accumulate if the wheelbarrow gets used.
--this script empties all wheelbarrows which have rocks stuck in them.


for _,e in ipairs(df.global.world.items.other.TOOL) do
    -- wheelbarrow must be on ground and not in a job
    if ((not e.flags.in_job) and e.flags.on_ground) then
        if e.subtype.id == "ITEM_TOOL_WHEELBARROW" then
            local items = dfhack.items.getContainedItems(e)
            print('Emptying wheelbarrow: ' .. dfhack.items.getDescription(e, 0))
            if #items > 0 then
                print('Emptying wheelbarrow: ' .. dfhack.items.getDescription(e, 0))
                for _,i in ipairs(items) do
                    print('  ' .. dfhack.items.getDescription(i, 0))
                    dfhack.items.moveToGround(i, e.pos)
                end
            end
        end
    end
end
