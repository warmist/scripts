
for _,e in ipairs(df.global.world.items.other.TOOL) do
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